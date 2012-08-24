class HomeController < ApplicationController

  def index
    render :json => {
      :links => { :ontologies => $BASE_UI_URL + Ontology.path.gsub("/:ontology", "") },
      :future_links => {
        :search => "#{$BASE_UI_URL}/search",
        :annotator => "#{$BASE_UI_URL}/annotator",
        :resource_index => "#{$BASE_UI_URL}/resource_index",
        :mappings => "#{$BASE_UI_URL}/mappings",
        :reviews => "#{$BASE_UI_URL}/reviews",
        :notes => "#{$BASE_UI_URL}/notes",
        :views => "#{$BASE_UI_URL}/views",
        :categories => "#{$BASE_UI_URL}/categories",
        :groups => "#{$BASE_UI_URL}/groups",
        :metrics => "#{$BASE_UI_URL}/metrics",
        :projects => "#{$BASE_UI_URL}/projects"
      }
    }
  end

end
