require 'open-uri'
require 'json'
require 'cgi'

# Utility methods for working with RDF data, mainly returned SPARQL query results from 4store
class RDFUtil

  # Address for the 4store server
  @@endpoint = "http://bmir-dev1:8083/"
  # @@endpoint = "http://sparql.bioontology.org/sparql/?apikey=24e0e77e-54e0-11e0-9d7b-005056aa3316"

  # Group of lambdas for handling XSD type conversion
  XSD_LITERAL_CONVERT = {
    "http://www.w3.org/2001/XMLSchema#string" => lambda do |value|
      value
    end,
    "http://www.w3.org/2001/XMLSchema#boolean" => lambda do |value|
      value.eql?("true")
    end,
    "http://www.w3.org/2001/XMLSchema#integer" => lambda do |value|
      value.to_i
    end,
    "http://www.w3.org/2001/XMLSchema#double" => lambda do |value|
      value.to_f
    end,
    "http://www.w3.org/2001/XMLSchema#float" => lambda do |value|
      value.to_f
    end,
    "http://www.w3.org/2001/XMLSchema#dateTime" => lambda do |value|
      DateTime.parse(value)
    end,
    "http://www.w3.org/1999/02/22-rdf-syntax-ns#XMLLiteral" => lambda do |value|
      value
    end,
    "http://www.w3.org/2001/XMLSchema#datetime" => lambda do |value|
      DateTime.parse(value)
    end
  }

  # Takes returned value information and converts to appropriate Ruby object types
  # @param [String] type of value
  # @param [String] XSD datatype
  # @param [String] value in string form
  # @return [Object] converted value
  def self.convert_xsd(type, datatype, value)
    case type
      when "uri"
        value
      when "bnode"
        value
      when "literal"
        puts datatype if XSD_LITERAL_CONVERT[datatype].nil?
        # debugger if XSD_LITERAL_CONVERT[datatype].nil?
        XSD_LITERAL_CONVERT[datatype].call(value) rescue value
    end
  end

  # Convert a list of SPARQL JSON values to proper Ruby objects
  # @param [Array] list of results. Each item should be a hash with type, datatype, and value
  # @return [Array] list of converted values
  def self.sparql_select_values(results)
    container = []
    results.each do |result|
      triple = result.first[1]
      container << convert_xsd(triple["type"], triple["datatype"], triple["value"])
    end
    container
  end

  # Perform a query against the triplestore using HTTP
  # @param [String] properly formed SPARQL query
  # @option options [Symbol] :full default: false. Setting to 'true' will return the whole json, false tries to find bindings and return those.
  def self.query(query, options = {})
    options[:full] ||= false
    start = Time.now
    data = open("#{@@endpoint}sparql/?query=#{CGI.escape(query)}&output=json").read
    parsed_data = JSON.parse(data)
    # puts "Query from #{caller[0].split(":")[0].split("/").last}:#{caller[0].split(" ")[1].gsub("`", "").gsub("'", "")} #{Time.now - start}s"
    options[:full] = true unless parsed_data["results"] && options[:full] == false
    options[:full] == true ? parsed_data : parsed_data["results"]["bindings"]
  end
end