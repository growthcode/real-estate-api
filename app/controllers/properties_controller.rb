class PropertiesController < ApplicationController
  def estimate
    return unless params[:address].present?

    response = RealEstateService.estimate_value(
      address: params[:address],
      city: params[:city],
      state_code: params[:state_code],
      zip: params[:zip]
    )
    @estimate = response.dig("data") || {}
  end
end
