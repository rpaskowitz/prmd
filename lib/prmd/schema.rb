module Prmd
  class Schema

    def [](key)
      @data[key]
    end

    def []=(key, value)
      @data[key] = value
    end

    def initialize(new_data = {})
      convert_type_to_array = lambda do |datum|
        case datum
        when Array
          datum.map { |element| convert_type_to_array.call(element) }
        when Hash
          if datum.has_key?('type') && datum['type'].is_a?(String)
            datum['type'] = [*datum['type']]
          end
          datum.each { |k,v| datum[k] = convert_type_to_array.call(v) }
        else
          datum
        end
      end
      @data = convert_type_to_array.call(new_data)
      @schemata_examples = {}
    end

    def dereference(reference)
      if reference.is_a?(Hash)
        if reference.has_key?('$ref')
          value = reference.dup
          key = value.delete('$ref')
        else
          return [nil, reference] # no dereference needed
        end
      else
        key, value = reference, {}
      end
      begin
        datum = @data
        key.gsub(%r{[^#]*#/}, '').split('/').each do |fragment|
          datum = datum[fragment]
        end
        # last dereference will have nil key, so compact it out
        # [-2..-1] should be the final key reached before deref
        dereferenced_key, dereferenced_value = dereference(datum)
        [
          [key, dereferenced_key].compact.last,
          [dereferenced_value, value].inject({}) { |composite, element| composite.merge(element) }
        ]
      rescue => error
        $stderr.puts("Failed to dereference `#{key}`")
        raise(error)
      end
    end

    def schema_value_example(value)
      if value.has_key?('example')
        value['example']
      elsif value.has_key?('anyOf')
        ref = value['anyOf'].detect {|ref| ref['$ref'].split('/').last == 'id'} || value['anyOf'].first
        schema_example(ref)
      elsif value.has_key?('properties') # nested properties
        schema_example(value)
      elsif value.has_key?('items') # array of objects
        _, items = dereference(value['items'])
        if value['items'].has_key?('example')
          [items['example']]
        else
          [schema_example(items)]
        end
      end
    end

    def schema_example(schema)
      _, _schema = dereference(schema)

      if _schema.has_key?('example')
        _schema['example']
      elsif _schema.has_key?('allOf')
        example = {}
        _schema['allOf'].each do |object|
          temp_example = {}
          if object.has_key?("$ref")
            temp_example = schemata_example(object['$ref'].split('/').last)
          else            
            temp_example = schema_example(object)
          end
          temp_example.each do |key, value|
            example[key] = value
          end
        end
        example
      elsif _schema.has_key?('properties')
        example = {}
        _schema['properties'].each do |key, value|
          _, value = dereference(value)
          example[key] = schema_value_example(value)
        end
        example
      elsif _schema.has_key?('items')
        schema_value_example(_schema)
      end
    end

    def schemata_example(schemata_id)
      _, schema = dereference("#/definitions/#{schemata_id}")
      @schemata_examples[schemata_id] ||= begin
        schema_example(schema)
      end
    end

    def href
      (@data['links'].detect { |link| link['rel'] == 'self' } || {})['href']
    end

    def to_json
      new_json = JSON.pretty_generate(@data)
      # nuke empty lines
      new_json = new_json.split("\n").delete_if {|line| line.empty?}.join("\n") + "\n"
      new_json
    end

    def to_yaml
      YAML.dump(@data)
    end

    def to_s
      to_json
    end

  end
end
