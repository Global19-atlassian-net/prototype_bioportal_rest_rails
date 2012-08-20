class OntologiesController < ApplicationController

  def index
    ontologies = Ontology.all
    render :json => ontologies.as_json(serializer_options)
  end

  def show
    ont = Ontology.find(params[:id], :version => params[:version])
    render :json => ont.as_json(serializer_options)
  end

end
