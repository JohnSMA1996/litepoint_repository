class Unit < ApplicationRecord
    #has_one_attached :file, dependent: :destroy
    #has_many_attached :files, dependent: :destroy
    has_one_attached :text_file
end
