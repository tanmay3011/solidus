require 'spec_helper'

describe Spree::ProductProperty, type: :model do
  let(:product_property) { create(:product_property) }

  context "touching" do
    let(:product) { product_property.product }

    before do
      product.update_columns(updated_at: 1.day.ago)
    end

    subject { product_property.touch }

    it "touches the product" do
      expect { subject }.to change { product.reload.updated_at }
    end
  end

  context 'property_name=' do
    it "should assign property" do
      product_property.property_name = "Size"
      expect(product_property.property.name).to eq('Size')
    end
  end
end
