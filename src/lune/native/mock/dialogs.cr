{% if flag?(:lune_native_test_mock) %}
  module Lune
    module Native
      module DialogsMock
        record Call, method : Symbol, title : String, default_name : String = ""

        @@calls = [] of Call
        @@next_open_result : String? = nil
        @@next_open_dir_result : String? = nil
        @@next_open_files_result : Array(String) = [] of String
        @@next_save_result : String? = nil
        @@next_message_result : String = "Ok"

        class_getter calls

        def self.reset
          @@calls.clear
          @@next_open_result = nil
          @@next_open_dir_result = nil
          @@next_open_files_result = [] of String
          @@next_save_result = nil
          @@next_message_result = "Ok"
        end

        def self.stub_open(path : String?)
          @@next_open_result = path
        end

        def self.stub_open_dir(path : String?)
          @@next_open_dir_result = path
        end

        def self.stub_open_files(paths : Array(String))
          @@next_open_files_result = paths
        end

        def self.stub_save(path : String?)
          @@next_save_result = path
        end

        def self.stub_message(result : String)
          @@next_message_result = result
        end

        def self.record_open(title : String) : String?
          @@calls << Call.new(:open_file, title)
          @@next_open_result
        end

        def self.record_open_dir(title : String) : String?
          @@calls << Call.new(:open_dir, title)
          @@next_open_dir_result
        end

        def self.record_open_files(title : String) : Array(String)
          @@calls << Call.new(:open_files, title)
          @@next_open_files_result
        end

        def self.record_save(title : String, default_name : String) : String?
          @@calls << Call.new(:save_file, title, default_name)
          @@next_save_result
        end

        def self.record_message(type : Int32, title : String) : String
          @@calls << Call.new(:message, title)
          @@next_message_result
        end
      end
    end
  end
{% end %}
