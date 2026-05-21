{% if flag?(:win32) %}
  module Lune
    module Native
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
    end
  end
{% end %}
