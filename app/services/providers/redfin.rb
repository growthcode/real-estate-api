module Providers
  # API: Unofficial Redfin by apidojo on RapidAPI
  # Subscribe at: https://rapidapi.com/apidojo/api/unofficial-redfin
  # Host: unofficial-redfin.p.rapidapi.com
  class Redfin
    include HTTParty

    BASE_URL = "https://unofficial-redfin.p.rapidapi.com"
    HEADERS = {
      "x-rapidapi-key"  => ENV.fetch("RAPIDAPI_KEY", ""),
      "x-rapidapi-host" => "unofficial-redfin.p.rapidapi.com"
    }.freeze

    PROPERTY_TYPE_MAP = {
      "single_family" => 1,
      "townhomes"     => 2,
      "condos"        => 3,
      "multi_family"  => 5
    }.freeze

    def self.search(city:, state_code:, limit: 200,
                    price_min: nil, price_max: nil,
                    sqft_min: nil, sqft_max: nil,
                    home_type: nil, sort_field: "list_date", sort_dir: "desc")
      # Step 1: resolve city to a Redfin region_id
      region = get_region(city, state_code)
      return { listings: [], total: 0, raw: { error: "Could not resolve region for #{city}, #{state_code}" } } unless region

      params = {
        region_id:   region[:id],
        region_type: region[:type],
        num_homes:   [limit, 350].min,
        status:      1 # for sale
      }
      params[:min_price]   = price_min.to_i if price_min
      params[:max_price]   = price_max.to_i if price_max
      params[:min_sqft]    = sqft_min.to_i  if sqft_min
      params[:max_sqft]    = sqft_max.to_i  if sqft_max
      params[:property_type] = PROPERTY_TYPE_MAP[home_type] if home_type.present? && PROPERTY_TYPE_MAP[home_type]

      raw     = get("#{BASE_URL}/properties/list", headers: HEADERS, query: params)
      homes   = raw.dig("homes") || raw.dig("data", "homes") || []
      results = homes.map { |h| h["homeData"] || h }

      normalized = results.map { |l| normalize(l) }
      { listings: normalized, total: raw.dig("totalCount") || results.size, raw: raw.to_h }
    end

    def self.get_region(city, state_code)
      resp = get("#{BASE_URL}/locations/auto-complete",
                 headers: HEADERS,
                 query: { location: "#{city}, #{state_code}" })
      payload = resp["payload"] || resp
      item = Array(payload["exactMatch"] || payload["sections"]&.first&.dig("rows"))&.first
      return nil unless item
      { id: item["id"] || item["regionId"], type: item["type"] || 6 }
    rescue
      nil
    end

    def self.normalize(l)
      addr    = l["addressInfo"] || l["address"] || {}
      price   = l["priceInfo"]   || {}
      basic   = l["beds"]        || {}
      listing = l["listingInfo"] || {}

      {
        "property_id"     => (l["propertyId"] || l["listingId"])&.to_s,
        "list_price"      => (price["amount"] || l["price"]).to_i,
        "status"          => listing["status"] || "for_sale",
        "last_sold_price" => l["lastSoldPrice"]&.to_i,
        "last_sold_date"  => l["lastSoldDate"],
        "list_date"       => listing["listingDate"] || l["listDate"],
        "href"            => l["url"].then { |u| u&.start_with?("http") ? u : "https://www.redfin.com#{u}" },
        "primary_photo"   => l["photoUrls"]&.first.present? ? { "href" => l["photoUrls"].first } : nil,
        "location"        => {
          "address" => {
            "line"        => addr["streetLine"]  || addr["line"],
            "city"        => addr["city"],
            "state_code"  => addr["state"],
            "postal_code" => addr["zip"],
            "coordinate"  => { "lat" => addr["latitude"] || l["latitude"], "lon" => addr["longitude"] || l["longitude"] }
          }
        },
        "description"     => {
          "beds"               => (l["beds"] || basic["beds"]).to_i,
          "baths_consolidated" => l["baths"] || basic["baths"],
          "sqft"               => (l["sqFt"] || l["sqft"] || l["livingArea"]).to_i,
          "type"               => l["propertyType"],
          "year_built"         => l["yearBuilt"],
          "lot_sqft"           => l["lotSize"]&.to_i,
          "garage"             => nil,
          "stories"            => nil,
          "text"               => nil
        },
        "estimate"        => nil
      }
    end
  end
end
