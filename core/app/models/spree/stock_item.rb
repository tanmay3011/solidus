module Spree
  class StockItem < Spree::Base
    acts_as_paranoid

    belongs_to :stock_location, class_name: 'Spree::StockLocation', inverse_of: :stock_items
    belongs_to :variant, class_name: 'Spree::Variant', inverse_of: :stock_items
    has_many :stock_movements, inverse_of: :stock_item

    validates :stock_location, :variant, presence: true
    validates :variant_id, uniqueness: { scope: [:stock_location_id, :deleted_at] }, allow_blank: true
    validates :count_on_hand, numericality: { greater_than_or_equal_to: 0 }, if: :verify_count_on_hand?

    delegate :weight, :should_track_inventory?, to: :variant

    after_save :conditional_variant_touch, if: :changed?
    after_touch { variant.touch }

    self.whitelisted_ransackable_attributes = ['count_on_hand', 'stock_location_id']

    # @return [Array<Spree::InventoryUnit>] the backordered inventory units
    #   associated with this stock item
    def backordered_inventory_units
      Spree::InventoryUnit.backordered_for_stock_item(self)
    end

    # @return [String] the name of this stock item's variant
    def variant_name
      variant.name
    end

    # Adjusts the count on hand by a given value.
    #
    # @note This will cause backorders to be processed.
    # @param value [Fixnum] the amount to change the count on hand by, positive
    #   or negative values are valid
    def adjust_count_on_hand(value)
      self.with_lock do
        self.count_on_hand = self.count_on_hand + value
        process_backorders(count_on_hand - count_on_hand_was)

        self.save!
      end
    end

    # Sets this stock item's count on hand.
    #
    # @note This will cause backorders to be processed.
    # @param value [Fixnum] the desired count on hand
    def set_count_on_hand(value)
      self.count_on_hand = value
      process_backorders(count_on_hand - count_on_hand_was)

      self.save!
    end

    # @return [Boolean] true if this stock item's count on hand is not zero
    def in_stock?
      self.count_on_hand > 0
    end

    # @return [Boolean] true if this stock item can be included in a shipment
    def available?
      self.in_stock? || self.backorderable?
    end

    # @note This returns the variant regardless of whether it was soft
    #   deleted.
    # @return [Spree::Variant] this stock item's variant.
    def variant
      Spree::Variant.unscoped { super }
    end

    # Sets the count on hand to zero if it not already zero.
    #
    # @note This processes backorders if the count on hand is not zero.
    def reduce_count_on_hand_to_zero
      self.set_count_on_hand(0) if count_on_hand > 0
    end

    private
      def verify_count_on_hand?
        count_on_hand_changed? && !backorderable? && (count_on_hand < count_on_hand_was) && (count_on_hand < 0)
      end

      def count_on_hand=(value)
        write_attribute(:count_on_hand, value)
      end

      # Process backorders based on amount of stock received
      # If stock was -20 and is now -15 (increase of 5 units), then we should process 5 inventory orders.
      # If stock was -20 but then was -25 (decrease of 5 units), do nothing.
      def process_backorders(number)
        if number > 0
          backordered_inventory_units.first(number).each do |unit|
            unit.fill_backorder
          end
        end
      end

      def conditional_variant_touch
        variant.touch if inventory_cache_threshold.nil? || should_touch_variant?
      end

      def should_touch_variant?
        # the variant_id changes from nil when a new stock location is added
        inventory_cache_threshold &&
        (count_on_hand_changed? && count_on_hand_change.any? { |c| c < inventory_cache_threshold }) ||
        variant_id_changed?
      end

      def inventory_cache_threshold
        # only warn if store is setting binary_inventory_cache (default = false)
        @cache_threshold ||= if Spree::Config.binary_inventory_cache
          ActiveSupport::Deprecation.warn "Spree::Config.binary_inventory_cache=true is DEPRECATED. Instead use Spree::Config.inventory_cache_threshold=1"
          1
        else
          Spree::Config.inventory_cache_threshold
        end
      end
  end
end
