module Searchable


  # convenience, referenced from tasks/utils.rb as well
  def self.client; @client; end
  def self.client=(client); @client = client; end
  def self.index; Environment.config['elastic_search']['index']; end

  def self.query_for(query_string, params, search_fields)
    return unless query_string.present?

    {
      query_string: {
        query: query_string,
        default_operator: "AND",
        use_dis_max: true,
        fields: search_fields
      }
    }
  end

  def self.filter_for(filters)
    return nil unless filters.any?

    subfilters = filters.map do |field, filter|
      value, operator = filter
      subfilter_for field, value, operator
    end

    if subfilters.size == 1
      subfilters.first
    else
      {
        :and => {
          filters: subfilters,
          _cache: true
        }
      }
    end
  end

  def self.subfilter_for(field, value, operator)
    if operator == "exists"
      if value == false
        return {missing: {field: field.to_s}}
      else
        return {exists: {field: field.to_s}}
      end
    end

    if ["all", "in"].include?(operator)
      return {
        {"all" => "and", "in" => "or"}[operator] => value.map {|v| subfilter_for field, v, nil}
      }
    end

    if operator == "all"
      return {
        "and" => value.map {|v| subfilter_for field, v, nil}
      }
    elsif operator == "in"
      return {
        "or" => value.map {|v| subfilter_for field, v, nil}
      }
    elsif operator == "nin"
      return {
        "not" => {
          "or" => value.map {|v| subfilter_for field, v, nil}
        }
      }
    end

    subfilter = if value.is_a?(String)
      # strings can be filtered on ranges
      # especially effective on date fields forced to be strings
      if ["lt", "lte", "gt", "gte"].include?(operator)
        options = {operator => value.to_s}
        {range: {field.to_s => options}}
      else
        {
          query: {
            match: {
              field.to_s => {
                query: value,
                type: "phrase"
              }
            }
          }
        }
      end

    elsif value.is_a?(Boolean)
      # nothing less nor greater than the truth
      {
        term: {
          field.to_s => value.to_s
        }
      }

    elsif value.is_a?(Fixnum)
      if ["lt", "lte", "gt", "gte"].include?(operator)
        options = {operator => value.to_s}
        {range: {field.to_s => options}}
      else
        {term: {field.to_s => value.to_s}}
      end

    elsif value.is_a?(Time)
      # ES doesn't have time-specific functions, we just
      # convert the Time back to its normal RFC 3339 (UTC)
      # format and treat it like a string
      if ["lt", "lte", "gt", "gte"].include?(operator)
        options = {operator => value.iso8601}
        {range: {field.to_s => options}}
      else
        {
          query: {
            match: {
              field.to_s => {
                query: value.iso8601,
                type: "phrase"
              }
            }
          }
        }
      end
    end

    # reverse the subfilter if there was a 'not'
    if operator == "not"
      {"not" => subfilter}
    else
      subfilter
    end
  end

  def self.search_fields_for(models)
    models = [models] unless models.is_a?(Array)
    models.map {|m| m.search_fields.map {|field| field.to_s}}.flatten.uniq
  end

  def self.documents_for(query_string, fields, raw_results)
    raw_results['hits']['hits'].map {|hit| attributes_for query_string, hit, fields}
  end

  def self.mapping_for(models)
    models.map {|model| model.to_s.underscore.pluralize}.join ","
  end

  def self.search_for(query_string, models, query, filter, fields, order, pagination, profiles, other)
    request = request_for models, query, filter, fields, order, pagination, profiles, other

    begin
      results = client.search request
    rescue Exception => exc
      return {
        error: exception_to_hash(exc)
      }
    end

    documents = Searchable.documents_for query_string, fields, results

    {
      results: documents,
      count: results['hits']['total'],
      page: {
        count: documents.size,
        per_page: pagination[:per_page],
        page: pagination[:page]
      }
    }
  end

  def self.explain_for(query_string, models, query, filter, fields, order, pagination, profiles, other)
    request = request_for models, query, filter, fields, order, pagination, profiles, other

    begin
      start = Time.now
      response = client.search request
      elapsed = Time.now - start
    rescue Exception => exc
      return {
        error: exception_to_hash(exc),
        request: request
      }
    end
    {
      query: query_string,
      count: response['hits']['total'],
      elapsed: elapsed,
      request: request,
      response: response
    }
  end

  def self.exception_to_hash(exception)
    {
      'backtrace' => exception.backtrace,
      'message' => exception.message,
      'type' => exception.class.to_s
    }
  end

  def self.other_options_for(params, search_fields)
    options = {
      # turn on explanation fields on each hit, for the discerning debugger
      explain: params[:explain].present?,

      # compute a score even if the sort is not on the score
      track_scores: true
    }

    if params[:highlight] == "true"

      highlight = {
        fields: {},
        order: "score",
        fragment_size: 200
      }

      search_fields.each {|field| highlight[:fields][field] = {}}

      if params["highlight.tags"].present?
        pre, post = params["highlight.tags"].split ','
        highlight[:pre_tags] = [pre || '']
        highlight[:post_tags] = [post || '']
      end

      if params["highlight.size"].present?
        highlight[:fragment_size] = params["highlight.size"].to_i
      end

      options[:highlight] = highlight
    end

    options
  end

  def self.profiles_for(models, params)
    models = [models] unless models.is_a?(Array)
    if params.has_key? "search.profile"
      models.map {|m| m.search_profiles[params["search.profile"].to_sym]}.flatten
    end
  end

  def self.request_for(models, query, filter, fields, order, pagination, profiles, other)
    from = pagination[:per_page] * (pagination[:page]-1)
    size = pagination[:per_page]

    # construct final query/filter pair
    query_filter = {}

    # if there's a custom filter, use that as the base query
    if profiles and query

      profile = profiles.first

      # the query is the custom filter scoring
      query_filter[:query] = {
        custom_filters_score: {
          query: {
            multi_match: {
              query: query[:query_string][:query],
              use_dis_max: true,
              fields: profile[:fields]
            }
          },
          params: {
            now: Time.now.to_i * 1000
          },
          filters: profile[:filters]
        },
        fields: query[:query_string][:fields]
      }

      # and include any further filter on it
      if filter
        query_filter[:query][:filter] = filter
      end

    # if no custom filter, and we have both a query and a filter,
    # use a "filtered query"
    elsif query and filter
      query_filter = {
        query: {
          filtered: {
            filter: filter,
            query: query
          }
        }
      }

    # otherwise (just a query, or just a filter) pass that on
    elsif query
      query_filter = {query: query}
    elsif filter
      query_filter = {post_filter: filter}
    else
      # uh oh?
    end

    sort = order.map do |field, direction|
      {field => direction}
    end

    body = {
      from: from,
      size: size,

      sort: sort,
      _source: fields
    }.merge(query_filter).merge(other)

    {
      index: Searchable.index,
      type: mapping_for(models),
      body: body
    }
  end

  def self.attributes_for(query_string, hit, fields)
    attributes = {}
    search = {score: hit['_score'], type: hit['_type'].singularize}

    hit['fields'] ||= {}

    if hit['highlight']
      search[:highlight] = hit['highlight']
    end

    hit['_source'].each do |key, value|
      break_out attributes, key.split('.'), value
    end

    attributes.merge search: search
  end

  # helper function to recursively rewrite a hash to break out dot-separated fields into sub-documents
  def self.break_out(hash, keys, final_value)
    if keys.size > 1
      first = keys.first
      rest = keys[1..-1]

      # default to on
      hash[first] ||= {}

      break_out hash[first], rest, final_value
    else
      hash[keys.first] = final_value
    end
  end

end