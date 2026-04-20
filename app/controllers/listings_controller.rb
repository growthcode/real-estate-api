class ListingsController < ApplicationController
  def search
    city       = params[:city].presence || "Las Vegas"
    state_code = params[:state_code].presence || "NV"

    response = RealEstateService.search_listings(city: city, state_code: state_code, limit: 20)
    @listings = response.dig("data", "home_search", "results") || []
    @query = { city: city, state_code: state_code }
  end

  def show
    response = RealEstateService.property_detail(params[:id])
    @property = response.dig("data", "home") || {}
  end
end
