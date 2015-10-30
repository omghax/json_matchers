require "json_schema"

module JsonMatchers
  class Matcher
    def initialize(schema_path, **options)
      @schema_path = schema_path
      @options = options
    end

    def matches?(response)
      @response = response

      begin
        add_schemata_to_document_store
        schema_data = JSON.parse(File.read(@schema_path.to_s))
        response_body = JSON.parse(@response.body)
        json_schema = JsonSchema.parse!(schema_data)

        json_schema.expand_references!(store: document_store)
        json_schema.validate!(response_body)
      rescue RuntimeError => ex
        @validation_failure_message = ex.message
        return false
      rescue JsonSchema::SchemaError, JSON::ParserError => ex
        raise InvalidSchemaError
      end

      true
    end

    def validation_failure_message
      @validation_failure_message.to_s
    end

    private

    attr_reader :schema_path, :options

    def add_schemata_to_document_store
      Dir.glob("#{JsonMatchers.schema_root}/**/*.json").each do |path|
        schema_data = JSON.parse(File.read(path))
        extra_schema = JsonSchema.parse!(schema_data)
        document_store.add_schema(extra_schema)
      end
    end

    def document_store
      @document_store ||= JsonSchema::DocumentStore.new
    end
  end
end
