require "sqlite3"
require "base64"

module Lune
  module Capabilities
    class Sqlite < Lune::Capability
      include Lune::Bindable
      include Capability::Lifecycle

      DESCRIPTOR = Descriptor.new(id: :sqlite, label: "Sqlite")

      def descriptor : Descriptor
        DESCRIPTOR
      end

      @databases = {} of String => DB::Database
      @mu = Mutex.new

      @[Lune::Bind(async: true)]
      def open(path : String) : String
        uri = path == ":memory:" ? "sqlite3::memory:" : "sqlite3:#{path}"
        database = DB.open(uri)
        id = Random.new.hex(8)
        @mu.synchronize { @databases[id] = database }
        id
      end

      @[Lune::Bind(async: true)]
      @[Lune::BindOverride(arg_names: ["db"])]
      def close(db_id : String) : Nil
        database = @mu.synchronize { @databases.delete(db_id) }
        database.try(&.close)
      end

      @[Lune::Bind(async: true)]
      @[Lune::BindOverride(arg_names: ["db", "sql", "params"], ts_return_type: "Promise<{ changes: number; lastInsertId: number }>")]
      def exec(db_id : String, sql : String, params : Array(JSON::Any)) : NamedTuple(changes: Int64, lastInsertId: Int64)
        database = @mu.synchronize { @databases[db_id]? }
        raise Lune::Error.new("sqlite_not_open", "No open database with id \"#{db_id}\"") unless database
        begin
          result = database.exec(sql, args: to_db_args(params))
          {changes: result.rows_affected, lastInsertId: result.last_insert_id}
        rescue ex : SQLite3::Exception | DB::Error
          raise Lune::Error.new("sqlite_error", ex.message || "SQLite error")
        end
      end

      @[Lune::Bind(async: true)]
      @[Lune::BindOverride(arg_names: ["db", "sql", "params"], ts_return_type: "Promise<Record<string, unknown>[]>")]
      def query(db_id : String, sql : String, params : Array(JSON::Any)) : Array(Hash(String, JSON::Any))
        database = @mu.synchronize { @databases[db_id]? }
        raise Lune::Error.new("sqlite_not_open", "No open database with id \"#{db_id}\"") unless database
        begin
          rows = [] of Hash(String, JSON::Any)
          database.query(sql, args: to_db_args(params)) do |rs|
            rs.each do
              row = {} of String => JSON::Any
              rs.column_count.times do |i|
                row[rs.column_name(i)] = db_val_to_json(rs.read(DB::Any))
              end
              rows << row
            end
          end
          rows
        rescue ex : SQLite3::Exception | DB::Error
          raise Lune::Error.new("sqlite_error", ex.message || "SQLite error")
        end
      end

      def shutdown : Nil
        dbs = @mu.synchronize { @databases.dup }
        dbs.each_value { |db| db.close rescue nil }
        @mu.synchronize { @databases.clear }
      end

      private def to_db_args(params : Array(JSON::Any)) : Array(DB::Any)
        params.map do |p|
          case raw = p.raw
          when Int64   then raw.as(DB::Any)
          when Float64 then raw.as(DB::Any)
          when String  then raw.as(DB::Any)
          when Bool    then (raw ? 1_i64 : 0_i64).as(DB::Any)
          when Nil     then nil.as(DB::Any)
          else              p.to_json.as(DB::Any)
          end
        end
      end

      private def db_val_to_json(val : DB::Any) : JSON::Any
        case val
        when Int16, Int32, Int64 then JSON::Any.new(val.to_i64)
        when Float32, Float64    then JSON::Any.new(val.to_f64)
        when String              then JSON::Any.new(val)
        when Bool                then JSON::Any.new(val)
        when Bytes               then JSON::Any.new(Base64.strict_encode(val))
        when Nil                 then JSON::Any.new(nil)
        else                          JSON::Any.new(val.to_s)
        end
      end
    end
  end
end
