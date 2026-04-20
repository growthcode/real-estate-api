class RealEstateService
  include HTTParty

  BASE_URL = "https://realty-in-us.p.rapidapi.com"
  HEADERS = {
    "x-rapidapi-key"  => ENV.fetch("RAPIDAPI_KEY", ""),
    "x-rapidapi-host" => "realty-in-us.p.rapidapi.com",
    "Content-Type"    => "application/json"
  }.freeze

  def self.search_listings(city:, state_code:, limit: 200, offset: 0,
                           price_min: nil, price_max: nil,
                           sqft_min: nil, sqft_max: nil,
                           home_type: nil, sort_field: "list_date", sort_dir: "desc")
    body = {
      city: city,
      state_code: state_code,
      limit: limit,
      offset: offset,
      status: ["for_sale"],
      sort: { direction: sort_dir, field: sort_field }
    }

    if price_min || price_max
      body[:list_price] = {}
      body[:list_price][:min] = price_min.to_i if price_min
      body[:list_price][:max] = price_max.to_i if price_max
    end

    if sqft_min || sqft_max
      body[:sqft] = {}
      body[:sqft][:min] = sqft_min.to_i if sqft_min
      body[:sqft][:max] = sqft_max.to_i if sqft_max
    end

    body[:type] = [home_type] if home_type.present?

    post("#{BASE_URL}/properties/v3/list", { headers: HEADERS, body: body.to_json })
  end

  def self.property_detail(property_id)
    get("#{BASE_URL}/properties/v3/detail", {
      query: { property_id: property_id },
      headers: HEADERS
    })
  end

  def self.estimate_value(address:, city:, state_code:, zip:)
    get("#{BASE_URL}/properties/v2/get-valuation", {
      query: { address: address, city: city, state_code: state_code, postal_code: zip },
      headers: HEADERS
    })
  end

  def self.market_trends(city:, state_code:)
    get("#{BASE_URL}/markets/v2/get-snapshot", {
      query: { city: city, state_code: state_code },
      headers: HEADERS
    })
  end
end
