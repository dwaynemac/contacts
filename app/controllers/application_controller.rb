require 'typhoeus_fix/array_decoder'

class ApplicationController < ActionController::Base

  protect_from_forgery

  include TyphoeusFix

  before_filter :decode_typhoeus_arrays

end
