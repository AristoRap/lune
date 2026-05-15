require "json"

module Lune
  annotation Bind; end

  module Bindable
    include Installable
    getter app : Lune::App = Lune::App.new

    macro included
      def install(app : Lune::App)
        {% verbatim do %}
          {% begin %}
            @app = app
            {% for m in @type.methods %}
              {% if ann = m.annotation(Lune::Bind) %}
              {% async = ann[:async] && ann[:async].id == "true" ? true : false %}
                app.bind(
                  namespace: {{ @type.name.stringify }},
                  method: {{ m.name.stringify }},
                  args: {{ m.args.map(&.restriction.stringify) }} of String,
                  return_type: {{ m.return_type.stringify }},
                  async: {{ async }},
                ) do |__args|
                  raise ArgumentError.new("expected {{ m.args.size }} arg(s), got #{__args.size}") unless __args.size == {{ m.args.size }}
                  {% for arg, i in m.args %}
                    # JSON::Any -> T  (T must include JSON::Serializable, or be a primitive)
                    __arg{{ i }} = {{ arg.restriction }}.from_json(__args[{{ i }}].to_json)
                  {% end %}
                  result = {{ m.name.id }}({% for arg, i in m.args %}{% if i > 0 %}, {% end %}__arg{{ i }}{% end %})
                  JSON.parse(result.to_json)
                end
              {% end %}
            {% end %}
          {% end %}
        {% end %}
      end
    end
  end
end
