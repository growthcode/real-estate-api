module Providers
  # API: Zillow56 by s.mahmoud97 on RapidAPI
  # Subscribe at: https://rapidapi.com/s.mahmoud97/api/zillow56
  # Host: zillow56.p.rapidapi.com
  class Zillow
    include HTTParty

    BASE_URL = "https://zillow56.p.rapidapi.com"
    HEADERS = {
      "x-rapidapi-key"  => ENV.fetch("RAPIDAPI_KEY", ""),
      "x-rapidapi-host" => "zillow56.p.rapidapi.com"
    }.freeze

    HOME_TYPE_MAP = {
      "single_family" => "SingleFamily",
      "townhomes"     => "Townhouse",
      "condos"        => "Condo",
      "multi_family"  => "MultiFamily"
    }.freeze

    def self.search(city:, state_code:, limit: 200,
                    price_min: nil, price_max: nil,
                    sqft_min: nil, sqft_max: nil,
                    home_type: nil, sort_field: "list_date", sort_dir: "desc")
      location = "#{city}, #{state_code}"
      params = { location: location, status: "forSale", output: "json", count: [limit, 40].min }
      params[:minPrice]    = price_min.to_i if price_min
      params[:maxPrice]    = price_max.to_i if price_max
      params[:minSqft]     = sqft_min.to_i  if sqft_min
      params[:maxSqft]     = sqft_max.to_i  if sqft_max
      params[:home_type]   = HOME_TYPE_MAP[home_type] if home_type.present? && HOME_TYPE_MAP[home_type]

      raw     = get("#{BASE_URL}/search", headers: HEADERS, query: params)
      results = raw["results"] || raw["props"] || []

      normalized = results.map { |l| normalize(l) }
      { listings: normalized, total: raw["totalResultCount"] || results.size, raw: raw.to_h }
    end

    def self.normalize(l)
      {
        "property_id"     => l["zpid"]&.to_s,
        "list_price"      => l["price"].to_i,
        "status"          => l["homeStatus"]&.downcase,
        "last_sold_price" => l["lastSoldPrice"]&.to_i,
        "last_sold_date"  => l["lastSoldDate"],
        "list_date"       => l["dateSoldString"] || l["datePostedString"],
        "href"            => l["detailUrl"].then { |u| u&.start_with?("http") ? u : "https://www.zillow.com#{u}" },
        "primary_photo"   => l["imgSrc"].present? ? { "href" => l["imgSrc"] } : nil,
        "location"        => {
          "address" => {
            "line"        => l["streetAddress"],
            "city"        => l["city"],
            "state_code"  => l["state"],
            "postal_code" => l["zipcode"],
            "coordinate"  => { "lat" => l["latitude"], "lon" => l["longitude"] }
          }
        },
        "description"     => {
          "beds"              => l["bedrooms"].to_i,
          "baths_consolidated" => l["bathrooms"],
          "sqft"              => l["livingArea"].to_i,
          "type"              => l["homeType"],
          "year_built"        => l["yearBuilt"],
          "lot_sqft"          => l["lotAreaValue"]&.to_i,
          "garage"            => nil,
          "stories"           => nil,
          "text"              => nil
        },
        "estimate"        => l["zestimate"] ? { "estimate" => l["zestimate"].to_i } : nil
      }
    end
  end
end
