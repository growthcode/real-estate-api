class ListingsController < ApplicationController
  def search
    city       = params[:city].presence || "Las Vegas"
    state_code = params[:state_code].presence || "NV"
    price_min  = params[:price_min].presence || 200_000
    price_max  = params[:price_max].presence || 650_000
    sqft_min   = params[:sqft_min].presence || 1_750
    sqft_max   = params[:sqft_max].presence
    home_type  = params[:home_type].presence || "single_family"
    sort_field = params[:sort_field].presence || "best_value"
    sort_dir   = params[:sort_dir].presence || "desc"
    best_value = sort_field == "best_value"
    api_sort_field, api_sort_dir = case sort_field
      when "best_value"      then ["list_date",  "desc"]
      when "list_price_asc"  then ["list_price", "asc"]
      when "list_price"      then ["list_price", "desc"]
      when "sqft"            then ["sqft",        "asc"]
      else                        [sort_field,    sort_dir]
    end

    response = RealEstateService.search_listings(
      city: city, state_code: state_code, limit: 200,
      price_min: price_min, price_max: price_max,
      sqft_min: sqft_min, sqft_max: sqft_max,
      home_type: home_type,
      sort_field: api_sort_field, sort_dir: api_sort_dir
    )

    raw_results = response.dig("data", "home_search", "results") ||
                  response.dig("data", "results") || []

    scored    = ValueScorer.score_all(raw_results)
    @listings = if best_value
      scored
    else
      scored.sort_by { |l|
        case sort_field
        when "list_price_asc" then  l["list_price"].to_i
        when "list_price"     then -l["list_price"].to_i
        when "sqft"           then  l.dig("description", "sqft").to_i
        else 0
        end
      }
    end
    @raw_response = response.to_h
    @query        = { city: city, state_code: state_code, price_min: price_min, price_max: price_max,
                      sqft_min: sqft_min, sqft_max: sqft_max, home_type: home_type,
                      sort_field: sort_field, sort_dir: sort_dir }
    @map_markers  = build_markers(@listings)
  end

  private

  def build_markers(listings)
    listings.filter_map do |l|
      lat = extract_lat(l)
      lng = extract_lng(l)
      next unless lat && lng

      {
        lat:             lat,
        lng:             lng,
        id:              l["property_id"],
        address:         l.dig("location", "address", "line"),
        city:            l.dig("location", "address", "city"),
        state:           l.dig("location", "address", "state_code"),
        zip:             l.dig("location", "address", "postal_code"),
        price:           l["list_price"],
        estimate:        l.dig("estimate", "estimate"),
        last_sold_price: l["last_sold_price"],
        last_sold_date:  l["last_sold_date"],
        beds:            l.dig("description", "beds"),
        baths:           l.dig("description", "baths_consolidated") || l.dig("description", "baths"),
        sqft:            l.dig("description", "sqft"),
        list_date:       l["list_date"],
        realtor_url:     l["href"],
        score:           l.dig("_value", :score).to_i,
        badges:          l.dig("_value", :badges).map { |b| b[:label] }
      }
    end
  end

  def extract_lat(obj)
    obj.dig("location", "address", "coordinate", "lat")
  end

  def extract_lng(obj)
    obj.dig("location", "address", "coordinate", "lon")
  end
end
