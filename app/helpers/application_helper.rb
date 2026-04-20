module ApplicationHelper
  def price_per_sqft(price, sqft)
    return nil unless price.to_i > 0 && sqft.to_i > 0
    number_to_currency(price.to_f / sqft.to_f, precision: 0)
  end

  def annualized_change(list_price, sold_price, sold_date_str)
    return nil unless list_price.to_i > 0 && sold_price.to_i > 0 && sold_date_str.present?
    sold_date = Date.parse(sold_date_str.to_s) rescue nil
    return nil unless sold_date
    years = (Date.today - sold_date).to_f / 365.25
    return nil if years < 0.5
    total_pct  = ((list_price.to_f - sold_price.to_f) / sold_price.to_f * 100).round(1)
    annual_pct = ((list_price.to_f / sold_price.to_f) ** (1.0 / years) - 1) * 100
    { total: total_pct, annual: annual_pct.round(1), year: sold_date.year, sold_price: sold_price }
  end
end
