module Api
  
  module Helpers

    def query_string_for(params)
      params[:query].present? ? params[:query].strip.downcase : nil
    end

    def format_for(params)
      params[:format] || "json"
    end

    def filters_for(params)
      fields = {}
      params.keys.each do |key|
        if !magic_fields.include?(key) and params[key].present?
          fields[key] = params[key]
        end
      end

      operators = %w{gt lt gte lte not exists all in}

      filters = {}
      fields.each do |field, value|
        field, operator = field.split "__"
        operator = nil unless operators.include?(operator)
        value = value_for value

        if ["all", "in"].include?(operator)
          if value["|"]
            value = value.split "|"
          else
            operator = nil
          end
        end

        filters[field] = [value, operator]
      end

      if params[:citing]
        filters['citation_ids'] = [params[:citing], "all"]
      end

      filters
    end

    def fields_for(models, params)
      return nil if params[:fields] == "all"

      models = [models] unless models.is_a?(Array)

      fields = if params[:fields].blank?
        models.map {|model| model.basic_fields.map {|field| field.to_s}}.flatten
      else
        params[:fields].split ','
      end

      # don't allow fetching of full text through API
      fields.delete 'text'

      models.each do |model|
        fields << model.cite_key.to_s if model.cite_key
      end

      fields.uniq
    end

    def order_for(params, default_order)
      key = ["order.asc", "order.desc", "order"].find {|k| params[k]}
      if key
        field = params[key]
        direction = key.split(".")[1] || "desc"
      else
        field = default_order
        direction = "desc"
      end
      
      [field, direction]
    end

    # auto-detect type of argument - allow quotes to force string interpretation
    def value_for(value)
      if ["true", "false"].include? value # boolean
        value == "true"
      elsif value =~ /^\d+$/
        value.to_i
      elsif (value =~ /^\d\d\d\d-\d\d-\d\dT\d\d:\d\d:\d\dZ/)
        Time.zone.parse(value).utc rescue nil
      else # use quotes to force a value to be a string
        value.tr "\"", ""
      end
    end

    def pagination_for(params)
      default_per_page = 20
      max_per_page = 50
      max_page = 200000000 # let's keep it realistic
      
      # rein in per_page to somewhere between 1 and the max
      per_page = (params[:per_page] || default_per_page).to_i
      per_page = default_per_page if per_page <= 0
      per_page = max_per_page if per_page > max_per_page
      
      # valid page number, please
      page = (params[:page] || 1).to_i
      page = 1 if page <= 0 or page > max_page

      # debug override - if all fields asked for, limit to 1
      per_page = 1 if params[:fields] == "all"
      
      {per_page: per_page, page: page}
    end

    # special fields used by the system, cannot be used on a model (on the top level)
    def magic_fields
      [
        "fields", 
        "order", "order.desc", "order.asc",
        "page", "per_page",

        "query",

        "highlight", "highlight.tags", "highlight.size",

        "citing", "citing.details",

        "explain", "format",

        "apikey",
        "callback", "_",
        "captures", "splat"
      ]
    end
  end

  # installs a few methods when Api::Model is mixed in
  module Model
    module ClassMethods
      def publicly(*types); types.any? ? @publicly = types : @publicly; end
      def basic_fields(*fields); fields.any? ? @basic_fields = fields : @basic_fields; end
      def search_fields(*fields); fields.any? ? @search_fields = fields : @search_fields; end
      def cite_key(key = nil); key ? @cite_key = key : @cite_key; end
    end
    def self.included(base)
      base.extend ClassMethods
      @models ||= []; @models << base
    end
    def self.models; @models; end
  end

  module Routes
    def queryable_route
      queryable = Model.models.select {|model| model.respond_to?(:publicly) and model.publicly and model.publicly.include?(:queryable)}
      @queryable_route ||= /^\/(#{queryable.map {|m| m.to_s.underscore.pluralize}.join "|"})$/
    end

    def searchable_route
      searchable = Model.models.select {|model| model.respond_to?(:publicly) and model.publicly and model.publicly.include?(:searchable)}
      @search_route ||= /^\/search\/((?:(?:#{searchable.map {|m| m.to_s.underscore.pluralize}.join "|"}),?)+)$/
    end
  end
  
end