module Lune
  module Native
    # Win32 process tree control via Job Objects. Windows has no POSIX-style
    # `kill(-pgid)` for terminating a process tree, and `Process.terminate`
    # only kills the leader -- so `cmd /c npm run dev` leaves orphaned npm.cmd
    # + node.exe holding the dev-server port. A Job Object with
    # JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE solves it: once we assign the leader
    # to the job, every descendant inherits it, and terminating (or merely
    # closing) the job atomically kills the whole tree.
    #
    # Lifecycle: `create` -> `assign(job, pid)` -> on shutdown
    # `terminate(job)` + `close(job)`. If lune.exe exits ungracefully the
    # kernel closes our handles, refcount drops to zero, and KILL_ON_JOB_CLOSE
    # cleans up anyway.
    {% if flag?(:win32) %}
      # Stdlib LibC already declares CreateJobObjectW, SetInformationJobObject,
      # AssignProcessToJobObject, OpenProcess, CloseHandle, plus the struct
      # JOBOBJECT_EXTENDED_LIMIT_INFORMATION and enum JOBOBJECTINFOCLASS in
      # c/jobapi2 + c/winnt. We use those directly via LibC.*.
      #
      # Only the things stdlib is missing get declared here, in our own lib
      # so we don't fight stdlib's existing `lib LibC` blocks at parse time.
      # The HANDLE param is Void* to dodge the cross-file type-scope issue
      # we'd otherwise hit by extending `lib LibC`.
      @[Link("kernel32")]
      lib LibKernel32JobExt
        fun terminate_job_object = "TerminateJobObject"(job : Void*, exit_code : UInt32) : Int32
        fun get_last_error_ext = "GetLastError" : UInt32
      end

      module ProcessGroupConsts
        JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE = 0x2000_u32

        PROCESS_TERMINATE = 0x0001_u32
        PROCESS_SET_QUOTA = 0x0100_u32
      end
    {% end %}

    module ProcessGroup
      {% if flag?(:win32) %}
        # Creates a job, assigns the current process (lune.exe) to it, and
        # returns the handle. Because the job has no breakaway flag, every
        # descendant Windows creates from this point on is forced into the
        # same job. When lune.exe dies for any reason (Ctrl-C, taskkill,
        # crash), the kernel closes the last handle to the job and
        # JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE kills the entire tree atomically.
        #
        # This is preferable to per-child `assign(job, pid)` because Crystal's
        # stdlib already puts each spawned child in its own internal job for
        # IOCP plumbing, and `AssignProcessToJobObject` on those children can
        # fail with ACCESS_DENIED depending on integrity/host context.
        def self.create_and_attach_self : Void*
          job = create
          current = LibC.GetCurrentProcess
          if LibC.AssignProcessToJobObject(job.as(LibC::HANDLE), current) == 0
            err = LibKernel32JobExt.get_last_error_ext
            LibC.CloseHandle(job.as(LibC::HANDLE))
            raise "AssignProcessToJobObject(self) failed last_error=#{err}"
          end
          job
        end

        # Returns a Job Object handle configured to kill all assigned
        # processes (and their descendants) when the handle is closed.
        # Raises if either CreateJobObjectW or SetInformationJobObject fails.
        def self.create : Void*
          job = LibC.CreateJobObjectW(nil, nil).as(Void*)
          raise "CreateJobObjectW failed" if job.null?

          info = LibC::JOBOBJECT_EXTENDED_LIMIT_INFORMATION.new
          info.basicLimitInformation.limitFlags = ProcessGroupConsts::JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE
          ok = LibC.SetInformationJobObject(
            job.as(LibC::HANDLE),
            LibC::JOBOBJECTINFOCLASS::ExtendedLimitInformation,
            pointerof(info).as(Void*),
            sizeof(LibC::JOBOBJECT_EXTENDED_LIMIT_INFORMATION).to_u32,
          )
          if ok == 0
            LibC.CloseHandle(job.as(LibC::HANDLE))
            raise "SetInformationJobObject failed"
          end
          job
        end

        # Attaches a running process (by pid) to the job. Returns false if
        # OpenProcess or AssignProcessToJobObject fails (e.g. process already
        # exited, or it's in an incompatible job on pre-Win8 -- rare).
        def self.assign(job : Void*, pid : Int) : Bool
          access = ProcessGroupConsts::PROCESS_TERMINATE |
                   ProcessGroupConsts::PROCESS_SET_QUOTA |
                   LibC::PROCESS_QUERY_INFORMATION.to_u32!
          handle = LibC.OpenProcess(access, 0, pid.to_u32)
          return false if handle.address == 0
          ok = LibC.AssignProcessToJobObject(job.as(LibC::HANDLE), handle) != 0
          LibC.CloseHandle(handle)
          ok
        end

        def self.terminate(job : Void*) : Nil
          LibKernel32JobExt.terminate_job_object(job, 1_u32)
        end

        def self.close(job : Void*) : Nil
          LibC.CloseHandle(job.as(LibC::HANDLE))
        end
      {% end %}
    end
  end
end
