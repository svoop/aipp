class Array

  # Convert array of namespaces to constant.
  #
  # @example
  #   %i(AIPP AIP Base).constantize   # => AIPP::AIP::Base
  #
  # @return [Class, Module] converted array
  def constantize
    map(&:to_s).join('::').constantize
  end

end
