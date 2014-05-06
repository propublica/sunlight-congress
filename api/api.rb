module Api

  module Helpers

    def query_string_for(params)
      params[:query].present? ? params[:query].strip : nil
    end

    def format_for(params)
      params[:format] || "json"
    end

    def filters_for(model, params)
      fields = {}
      params.keys.each do |key|
        if !magic_fields.include?(key) and params[key].present?
          fields[key] = params[key]
        end
      end

      operators = %w{gt lt gte lte not exists all in nin}

      # translate citation requests
      if params[:citing]
        fields['citation_ids__all'] = params[:citing]
      end

      filters = {}
      fields.each do |field, value|
        # we don't allow bracket based syntax, all instances of it are an error
        next if value.is_a?(Hash) or value.is_a?(Array)

        field, operator = field.split "__"
        operator = nil unless operators.include?(operator)

        if ["all", "in", "nin"].include?(operator)
          value = value.split("|").map {|v| value_for v}
        else
          value = value_for value
        end

        filters[field] = [value, operator]
      end

      # special case: default to in_office legislators
      # allow it to be overridden
      if model == Legislator
        unless params['all_legislators'] == "true"
          filters['in_office'] ||= [true, nil]
        end
      end

      # special case: default to current committees
      # no override
      if model == Committee
        filters['current'] = [true, nil]
      end

      # TEMPORARY special case:
      # default to upcoming bills ahead of a week ago
      # this will be killed when we've had a chance to update our docs,
      # and give clients some time to update.
      #
      # allow it to be overridden
      # this can be gotten rid of once we update our docs and apps
      if model == UpcomingBill
        unless filters['legislative_day']
          today = (Time.zone.now - 7.days).midnight.strftime "%Y-%m-%d"
          filters['legislative_day'] = [today, 'gte']
        end
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
      if params[:order]
        params[:order].split(",").map do |key|
          field, direction = key.split "__"
          direction ||= "desc"
          field = "_score" if field == "score" # convenience for users
          [field, direction]
        end
      else
        field = default_order
        direction = "desc"

        [[field, direction]]
      end
    end

    # auto-detect type of argument - allow quotes to force string interpretation
    def value_for(value)
      if ["true", "false"].include? value # boolean
        value == "true"
      elsif value =~ /^\d+$/
        value.to_i
      elsif (value =~ /^\d\d\d\d-\d\d-\d\dT\d\d:\d\d:\d\d(\.\d\d\d)?Z$/)
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
        # documented operators
        "fields",
        "order",
        "page", "per_page",
        "query",
        "highlight", "highlight.tags", "highlight.size",
        "explain",
        "apikey",
        "callback", "_", # (_ is what jQuery cache-busts JSONP with)

        "all_legislators", # special override

        # undocumented operators
        "citing", "citing.details",
        "format",
        "search.profile",

        # Sinatra-specific
        "captures", "splat"
      ]
    end
  end

  # installs a few methods when Api::Model is mixed in
  module Model
    module ClassMethods
      def publicly(*types); types.any? ? @publicly = types : @publicly; end
      def queryable?; (@publicly || []).include?(:queryable); end
      def searchable?; (@publicly || []).include?(:searchable); end
      def basic_fields(*fields); fields.any? ? @basic_fields = fields : @basic_fields; end
      def search_fields(*fields); fields.any? ? @search_fields = fields : @search_fields; end
      def search_profiles; @search_profiles; end
      def search_profile(name, fields: [], functions: []); @search_profiles ||= {}; @search_profiles[name] = {:fields => fields, :functions => functions}; end
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
      queryable = Model.models.select &:queryable?
      @queryable_route ||= /^\/(#{queryable.map {|m| m.to_s.underscore.pluralize}.join "|"})\/?$/
    end

    def searchable_route
      searchable = Model.models.select &:searchable?
      @search_route ||= /^\/((?:(?:#{searchable.map {|m| m.to_s.underscore.pluralize}.join "|"}),?)+)\/search\/?$/
    end
  end

end