module LuneCLI
  module Commands
    class Version
      def to_command : Argy::Command
        command = Argy::Command.new(
          use: "version",
          short: "Print the Lune version",
          long: "Print the Lune version and exit."
        )

        command.on_run do |_cmd, _args|
          puts version_string
        end

        command
      end

      def version_string : String
        "lune v#{Lune::VERSION}"
      end
    end
  end
end
