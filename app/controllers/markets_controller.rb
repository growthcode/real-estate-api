class MarketsController < ApplicationController
  def trends
    return unless params[:city].present?

    response = RealEstateService.market_trends(
      city: params[:city],
      state_code: params[:state_code]
    )
    @trends = response.dig("data") || {}
    @query = params.slice(:city, :state_code)
  end
end
