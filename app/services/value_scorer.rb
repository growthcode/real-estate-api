class ValueScorer
  ASSUMABLE_KEYWORDS = %w[assumable fha va].freeze

  def self.score(listing)
    points = 0
    badges = []

    points += price_history_score(listing, badges)
    points += assumable_score(listing, badges)
    points += price_reduced_score(listing, badges)

    { score: points, badges: badges }
  end

  def self.score_all(listings)
    listings
      .map { |l| l.merge("_value" => score(l)) }
      .sort_by { |l| -l["_value"][:score] }
  end

  private

  def self.price_history_score(listing, badges)
    sold_price = listing["last_sold_price"] ||
                 listing.dig("price_history", 0, "price") ||
                 listing.dig("sold_history", 0, "price")

    sold_date_str = listing["last_sold_date"] ||
                    listing.dig("price_history", 0, "date") ||
                    listing.dig("sold_history", 0, "date")

    return 0 unless sold_price && sold_date_str

    sold_date = Date.parse(sold_date_str.to_s) rescue nil
    return 0 unless sold_date

    years_ago = (Date.today - sold_date).to_f / 365
    return 0 unless years_ago.between?(2, 4)

    list_price = listing["list_price"].to_f
    return 0 if list_price.zero?

    diff_pct = ((list_price - sold_price) / sold_price.to_f * 100).round(1)

    # Price is within 10% of what it sold for 2-4 years ago = strong value in a down market
    if diff_pct.between?(-10, 10)
      badges << { label: "Price Match #{diff_pct > 0 ? "+#{diff_pct}" : diff_pct}% vs #{sold_date.year} sale", style: "success" }
      return 30
    elsif diff_pct.between?(-20, -10)
      badges << { label: "Below #{sold_date.year} sale price (#{diff_pct}%)", style: "success" }
      return 20
    end

    0
  end

  def self.assumable_score(listing, badges)
    searchable = [
      listing["tags"],
      listing.dig("mortgage_info", "type"),
      listing.dig("description", "text"),
      listing["financing_available"],
      listing["mls_remarks"]
    ].flatten.compact.join(" ").downcase

    if ASSUMABLE_KEYWORDS.any? { |kw| searchable.include?(kw) }
      type = searchable.match(/\b(fha|va)\b/)&.match(0)&.upcase || "Assumable"
      badges << { label: "#{type} Assumable Loan", style: "primary" }
      return 25
    end

    0
  end

  def self.price_reduced_score(listing, badges)
    reduced = listing["price_reduced_amount"] ||
              listing["price_reduction"] ||
              listing.dig("price_history", 0, "price_change")

    return 0 unless reduced.to_i > 0

    badges << { label: "Price Reduced $#{number_with_delimiter(reduced.to_i)}", style: "warning" }
    5
  end

  def self.number_with_delimiter(n)
    n.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
  end
end
