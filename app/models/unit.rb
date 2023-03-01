class Unit < ApplicationRecord
    has_one_attached :file, dependent: :destroy
    #has_many_attached :files, dependent: :destroy
end
