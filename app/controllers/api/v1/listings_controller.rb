class Api::V1::ListingsController < ApplicationController
  def show
    listing = Listing.find_by!(sku: params[:id])
    render json: serialize(listing)
  end

  def create
    listing = Listings::Upsert.new(sku: params[:sku], attrs: permitted_attrs).call
    render json: serialize(listing), status: :created
  end

  def update
    listing = Listings::Upsert.new(sku: params[:id], attrs: permitted_attrs).call
    render json: serialize(listing)
  end

  private

  def permitted_attrs
    params.permit(:seller_id, :title, :description, :brand, :category,
                  :price_cents, :currency, :inventory_qty,
                  attributes_data: {}).to_h
  end

  def serialize(listing)
    {
      sku: listing.sku,
      seller_id: listing.seller_id,
      title: listing.title,
      price_cents: listing.price_cents,
      inventory_qty: listing.inventory_qty,
      version: listing.version,
      channels: listing.channel_listings.map do |cl|
        {
          channel: cl.channel,
          status: cl.status,
          desired_version: cl.desired_version,
          applied_version: cl.applied_version,
          last_error: cl.last_error,
          last_synced_at: cl.last_synced_at,
          retry_count: cl.retry_count
        }
      end
    }
  end
end
