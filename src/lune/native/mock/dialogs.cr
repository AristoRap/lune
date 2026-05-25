{% if flag?(:lune_native_test_mock) %}
  module Lune
    module Native
      module DialogsMock
        alias FileFilter = NamedTuple(name: String, extensions: Array(String))

        record Call,
          method : Symbol,
          title : String,
          default_name : String = "",
          filters : Array(FileFilter) = [] of FileFilter

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

        def self.record_open(title : String, filters : Array(FileFilter)) : String?
          @@calls << Call.new(:open_file, title, "", filters)
          @@next_open_result
        end

        def self.record_open_dir(title : String) : String?
          @@calls << Call.new(:open_dir, title)
          @@next_open_dir_result
        end

        def self.record_open_files(title : String, filters : Array(FileFilter)) : Array(String)
          @@calls << Call.new(:open_files, title, "", filters)
          @@next_open_files_result
        end

        def self.record_save(title : String, default_name : String, filters : Array(FileFilter)) : String?
          @@calls << Call.new(:save_file, title, default_name, filters)
          @@next_save_result
        end

        def self.record_message(type : Int32, title : String) : String
          @@calls << Call.new(:message, title)
          @@next_message_result
        end
      end

      module Dialogs
        alias FileFilter = NamedTuple(name: String, extensions: Array(String))

        def self.open_file(title : String, filters : Array(FileFilter) = [] of FileFilter) : String?
          DialogsMock.record_open(title, filters)
        end

        def self.open_dir(title : String) : String?
          DialogsMock.record_open_dir(title)
        end

        def self.open_files(title : String, filters : Array(FileFilter) = [] of FileFilter) : Array(String)
          DialogsMock.record_open_files(title, filters)
        end

        def self.save_file(title : String, default_name : String = "", filters : Array(FileFilter) = [] of FileFilter) : String?
          DialogsMock.record_save(title, default_name, filters)
        end

        def self.message(type : Int32, title : String, message : String) : String
          DialogsMock.record_message(type, title)
        end
      end
    end
  end
{% end %}
