class Unit < ApplicationRecord
    has_one_attached :text_file
    has_one_attached :second_text_file
end
