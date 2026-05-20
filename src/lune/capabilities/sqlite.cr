require "sqlite3"
require "base64"

module Lune
  module Capabilities
    class Sqlite < Lune::Capability
      include Capability::Bindable
      include Capability::Lifecycle

      DESCRIPTOR = Descriptor.new(id: :sqlite, label: "Sqlite")

      def descriptor : Descriptor
        DESCRIPTOR
      end

      @databases = {} of String => DB::Database
      @mu = Mutex.new

      def install(ctx : BindCtx) : Nil
        ctx.register(Definition.new(
          name: "#{name}.open",
          args: ["String"],
          return_type: "String",
          arg_names: ["path"],
          async: true,
          ts_return_type: "Promise<string>",
          callback: ->(raw : Array(JSON::Any)) {
            path = raw[0].as_s
            uri = path == ":memory:" ? "sqlite3::memory:" : "sqlite3:#{path}"
            db = DB.open(uri)
            id = Random.new.hex(8)
            @mu.synchronize { @databases[id] = db }
            JSON::Any.new(id)
          },
        ).binding(binding_namespace))

        ctx.register(Definition.new(
          name: "#{name}.close",
          args: ["String"],
          return_type: "Nil",
          arg_names: ["db"],
          async: true,
          callback: ->(raw : Array(JSON::Any)) {
            id = raw[0].as_s
            database = @mu.synchronize { @databases.delete(id) }
            database.try(&.close)
            JSON::Any.new(nil)
          },
        ).binding(binding_namespace))

        ctx.register(Definition.new(
          name: "#{name}.exec",
          args: ["String", "String", "Array"],
          return_type: "Hash",
          arg_names: ["db", "sql", "params"],
          async: true,
          ts_return_type: "Promise<{ changes: number; lastInsertId: number }>",
          callback: ->(raw : Array(JSON::Any)) {
            id = raw[0].as_s
            sql = raw[1].as_s
            params = raw[2].as_a
            database = @mu.synchronize { @databases[id]? }
            raise Lune::Error.new("sqlite_not_open", "No open database with id \"#{id}\"") unless database
            begin
              result = database.exec(sql, args: to_db_args(params))
              JSON.parse({"changes" => result.rows_affected, "lastInsertId" => result.last_insert_id}.to_json)
            rescue ex : SQLite3::Exception | DB::Error
              raise Lune::Error.new("sqlite_error", ex.message || "SQLite error")
            end
          },
        ).binding(binding_namespace))

        ctx.register(Definition.new(
          name: "#{name}.query",
          args: ["String", "String", "Array"],
          return_type: "Array",
          arg_names: ["db", "sql", "params"],
          async: true,
          ts_return_type: "Promise<Record<string, unknown>[]>",
          callback: ->(raw : Array(JSON::Any)) {
            id = raw[0].as_s
            sql = raw[1].as_s
            params = raw[2].as_a
            database = @mu.synchronize { @databases[id]? }
            raise Lune::Error.new("sqlite_not_open", "No open database with id \"#{id}\"") unless database
            begin
              rows = [] of JSON::Any
              database.query(sql, args: to_db_args(params)) do |rs|
                rs.each do
                  row = {} of String => JSON::Any
                  rs.column_count.times do |i|
                    row[rs.column_name(i)] = db_val_to_json(rs.read(DB::Any))
                  end
                  rows << JSON::Any.new(row)
                end
              end
              JSON::Any.new(rows)
            rescue ex : SQLite3::Exception | DB::Error
              raise Lune::Error.new("sqlite_error", ex.message || "SQLite error")
            end
          },
        ).binding(binding_namespace))
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
