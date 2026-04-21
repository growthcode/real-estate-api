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
    best_value    = sort_field == "best_value"
    price_change  = sort_field.start_with?("price_change")
    dollar_change = sort_field.start_with?("dollar_change")
    api_sort_field, api_sort_dir = case sort_field
      when "best_value"                    then ["list_date",  "desc"]
      when "list_price_asc"                then ["list_price", "asc"]
      when "list_price"                    then ["list_price", "desc"]
      when "sqft"                          then ["sqft",        "asc"]
      when "price_change_asc",
           "price_change_desc",
           "dollar_change_asc",
           "dollar_change_desc"            then ["list_date",  "desc"]
      else                                      [sort_field,    sort_dir]
    end

    response = RealEstateService.search_listings(
      city: city, state_code: state_code, limit: 200,
      price_min: price_min, price_max: price_max,
      sqft_min: sqft_min, sqft_max: sqft_max,
      home_type: home_type,
      sort_field: api_sort_field, sort_dir: api_sort_dir
    )

    home_search = response.dig("data", "home_search") || {}
    raw_results = (home_search["results"] || response.dig("data", "results") || [])
                    .reject { |l| l["status"] == "contingent" }
    @total_available = home_search["total"]

    scored    = ValueScorer.score_all(raw_results)
    @listings = if best_value
      scored
    elsif dollar_change
      asc = sort_field == "dollar_change_asc"
      scored.sort_by { |l|
        val = dollar_per_year(l["list_price"], l["last_sold_price"], l["last_sold_date"])
        val.nil? ? Float::INFINITY : (asc ? val : -val)
      }
    elsif price_change
      asc = sort_field == "price_change_asc"
      scored.sort_by { |l|
        pct = annualized_pct(l["list_price"], l["last_sold_price"], l["last_sold_date"])
        pct.nil? ? Float::INFINITY : (asc ? pct : -pct)
      }
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

  def dollar_per_year(list_price, sold_price, sold_date_str)
    return nil unless list_price.to_i > 0 && sold_price.to_i > 0 && sold_date_str.present?
    sold_date = Date.parse(sold_date_str.to_s) rescue nil
    return nil unless sold_date
    years = (Date.today - sold_date).to_f / 365.25
    return nil if years < 0.5
    (list_price.to_f - sold_price.to_f) / years
  end

  def annualized_pct(list_price, sold_price, sold_date_str)
    return nil unless list_price.to_i > 0 && sold_price.to_i > 0 && sold_date_str.present?
    sold_date = Date.parse(sold_date_str.to_s) rescue nil
    return nil unless sold_date
    years = (Date.today - sold_date).to_f / 365.25
    return nil if years < 0.5
    ((list_price.to_f / sold_price.to_f) ** (1.0 / years) - 1) * 100
  end

  def extract_lat(obj)
    obj.dig("location", "address", "coordinate", "lat")
  end

  def extract_lng(obj)
    obj.dig("location", "address", "coordinate", "lon")
  end
end
