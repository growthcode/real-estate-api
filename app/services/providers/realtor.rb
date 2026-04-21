module Providers
  class Realtor
    include HTTParty

    BASE_URL = "https://realty-in-us.p.rapidapi.com"
    HEADERS = {
      "x-rapidapi-key"  => ENV.fetch("RAPIDAPI_KEY", ""),
      "x-rapidapi-host" => "realty-in-us.p.rapidapi.com",
      "Content-Type"    => "application/json"
    }.freeze

    def self.search(city:, state_code:, limit: 200,
                    price_min: nil, price_max: nil,
                    sqft_min: nil, sqft_max: nil,
                    home_type: nil, sort_field: "list_date", sort_dir: "desc")
      body = {
        city: city, state_code: state_code,
        limit: limit, offset: 0,
        status: ["for_sale"],
        sort: { direction: sort_dir, field: sort_field }
      }
      body[:list_price] = {}.tap { |h|
        h[:min] = price_min.to_i if price_min
        h[:max] = price_max.to_i if price_max
      } if price_min || price_max
      body[:sqft] = {}.tap { |h|
        h[:min] = sqft_min.to_i if sqft_min
        h[:max] = sqft_max.to_i if sqft_max
      } if sqft_min || sqft_max
      body[:type] = [home_type] if home_type.present?

      raw = post("#{BASE_URL}/properties/v3/list", headers: HEADERS, body: body.to_json)
      home_search = raw.dig("data", "home_search") || {}
      results     = home_search["results"] || raw.dig("data", "results") || []
      total       = home_search["total"]

      normalized = results
        .reject { |l| l["status"] == "contingent" }
        .map    { |l| normalize(l) }

      { listings: normalized, total: total, raw: raw.to_h }
    end

    def self.normalize(l)
      l # already in the native format the app was built around
    end
  end
end
