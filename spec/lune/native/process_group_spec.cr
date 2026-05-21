require "../../spec_helper"

{% if flag?(:win32) %}
  private def child_pids(parent_pid : Int, image : String) : Array(Int64)
    output = IO::Memory.new
    Process.run("powershell",
      ["-NoProfile", "-Command",
       "(Get-CimInstance Win32_Process -Filter \"Name='#{image}' AND ParentProcessId=#{parent_pid}\").ProcessId"],
      output: output,
      error: Process::Redirect::Close)
    output.to_s.lines.map(&.strip).reject(&.empty?).compact_map(&.to_i64?)
  end

  private def wait_until(timeout : Time::Span, & : -> Bool) : Bool
    deadline = Time.instant + timeout
    loop do
      return true if yield
      return false if Time.instant >= deadline
      sleep 100.milliseconds
    end
  end

  describe Lune::Native::ProcessGroup do
    it "create returns a non-null handle" do
      job = Lune::Native::ProcessGroup.create
      job.null?.should be_false
      Lune::Native::ProcessGroup.close(job)
    end

    it "assign returns true for a live process" do
      # `cmd /c pause` waits forever for input; with input closed it exits
      # immediately, but the handle is open long enough for AssignProcess.
      proc = Process.new("cmd", ["/c", "ping", "-n", "5", "127.0.0.1", "-w", "1000"],
        input: Process::Redirect::Close,
        output: Process::Redirect::Close,
        error: Process::Redirect::Close)
      job = Lune::Native::ProcessGroup.create
      Lune::Native::ProcessGroup.assign(job, proc.pid).should be_true
      Lune::Native::ProcessGroup.terminate(job)
      Lune::Native::ProcessGroup.close(job)
      proc.wait
    end

    it "terminate kills the assigned process and its descendants" do
      # cmd /c ping -> cmd.exe spawns ping.exe as a child. Job-on-tree means
      # terminating the job must kill ping.exe too. This is the regression we
      # care about: orphaned node.exe holding the vite port after lune dev.
      proc = Process.new("cmd", ["/c", "ping", "-n", "30", "127.0.0.1", "-w", "1000"],
        input: Process::Redirect::Close,
        output: Process::Redirect::Close,
        error: Process::Redirect::Close)

      job = Lune::Native::ProcessGroup.create
      Lune::Native::ProcessGroup.assign(job, proc.pid).should be_true

      # Wait until ping.exe shows up as a child of our cmd.exe.
      appeared = wait_until(5.seconds) { !child_pids(proc.pid, "ping.exe").empty? }
      appeared.should be_true

      Lune::Native::ProcessGroup.terminate(job)
      Lune::Native::ProcessGroup.close(job)

      # After terminate, ping.exe must be gone. We can't query parent linkage
      # for a dead cmd.exe (it'll be reaped too), so just confirm neither the
      # cmd.exe leader nor any orphaned ping.exe with that ppid is alive.
      gone = wait_until(5.seconds) { child_pids(proc.pid, "ping.exe").empty? }
      gone.should be_true

      proc.wait
    end

    # MUST run last: it puts the spec runner itself into a job with
    # KILL_ON_JOB_CLOSE. Earlier tests aren't affected because Crystal puts
    # each spawned child in a SILENT_BREAKAWAY_OK job that detaches from
    # ours -- but we still order this last to keep test interactions trivial.
    it "create_and_attach_self succeeds for the current process" do
      # If the current process can't be put in a fresh job, the dev shepherd
      # can't cleanup its tree on death -- regression-guard against that.
      # We intentionally don't `close` the returned handle: with the spec
      # runner inside the job, closing the last handle triggers
      # KILL_ON_JOB_CLOSE and would terminate the runner mid-suite. The OS
      # reclaims on process exit.
      job = Lune::Native::ProcessGroup.create_and_attach_self
      job.null?.should be_false
    end
  end
{% end %}
