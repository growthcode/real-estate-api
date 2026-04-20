class RealEstateService
  include HTTParty

  BASE_URL = "https://realty-in-us.p.rapidapi.com"
  HEADERS = {
    "x-rapidapi-key"  => ENV.fetch("RAPIDAPI_KEY", ""),
    "x-rapidapi-host" => "realty-in-us.p.rapidapi.com",
    "Content-Type"    => "application/json"
  }.freeze

  def self.search_listings(city:, state_code:, limit: 20, offset: 0)
    post("#{BASE_URL}/properties/v3/list", {
      headers: HEADERS,
      body: {
        city: city,
        state_code: state_code,
        limit: limit,
        offset: offset,
        status: ["for_sale"],
        sort: { direction: "desc", field: "list_date" }
      }.to_json
    })
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
