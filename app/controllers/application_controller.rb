require 'typhoeus/arrays_decoder'

class ApplicationController < ActionController::Base
  protect_from_forgery

  before_filter :decode_typhoeus_arrays

  private

  def decode_typhoeus_arrays
    deep_decode(params)
  end

  # Recursively decode Typhoeus encoded arrays
  def deep_decode(hash)
    return hash unless hash.is_a?(Hash)
    hash.each_pair do |key,value|
      if value.is_a?(Hash)
        deep_decode(value)
        hash[key] = value.decode_typhoeus_array
      end
    end
  end
end
