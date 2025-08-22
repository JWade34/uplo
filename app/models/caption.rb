class Caption < ApplicationRecord
  belongs_to :photo
  
  validates :content, presence: true
  validates :style, presence: true
  
  enum :style, {
    motivational: 'motivational',
    educational: 'educational', 
    friendly: 'friendly',
    professional: 'professional',
    inspiring: 'inspiring'
  }
  
  scope :recent, -> { order(created_at: :desc) }
end
