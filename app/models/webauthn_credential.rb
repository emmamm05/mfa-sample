class WebauthnCredential < ApplicationRecord
  belongs_to :user

  validates :external_id, presence: true, uniqueness: true
  validates :public_key, presence: true

  def transports_array
    (transports.presence || "").split(",").map(&:strip)
  end

  def transports_array=(arr)
    self.transports = Array(arr).join(",")
  end
end
