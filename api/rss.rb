# helpers purely to implement experimental RSS functionality

require 'ox'

helpers do

  # wildly standardized RSS XML model
  def rss(results, models, params)
    # only work for models that have been configured for RSS
    model = models.is_a?(Array) ? models.first : models
    halt 404 unless model.rss

    response['Content-Type'] = 'application/rss+xml; charset=utf-8'

    # wow, XML is truly an awful thing
    doc = Ox::Document.new version: "1.0", encoding: "utf-8"

    # doc info
    rss = Ox::Element.new "rss"
    rss[:version] = "2.0"
    rss["xmlns:atom"] = "http://www.w3.org/2005/Atom"

    # channel info
    channel = Ox::Element.new "channel"
    title = Ox::Element.new "title"
    title << "Sunlight Congress API Results"
    channel << title
    link = Ox::Element.new "link"
    link << "https://sunlightlabs.github.io/congress"
    channel << link
    description = Ox::Element.new "description"
    description << "Customized RSS results for the people and work of Congress, by the Sunlight Foundation."
    channel << description
    language = Ox::Element.new "language"
    language << "en-us"
    channel << language
    atom_link = Ox::Element.new "atom:link"
    atom_link[:href] = request.url
    atom_link[:rel] = "self"
    atom_link[:type] = "application/rss+xml"
    channel << atom_link


    results[:results].each do |result|
      channel << rss_item(result, model, params)
    end

    rss << channel
    doc << rss

    "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n" + Ox.dump(doc)
  end

  # model defines defaults for all 5, can also be overridden
  # by rss.[field] params.
  def rss_item(object, model, params)
    item = Ox::Element.new "item"

    if t = rss_field_for(object, model, params, :title)
      title = Ox::Element.new "title"
      title << t
      item << title
    end

    if desc = rss_field_for(object, model, params, :description)
      description = Ox::Element.new "description"
      description << Ox::CData.new(desc)
      item << description
    end

    if url = rss_field_for(object, model, params, :link)
      link = Ox::Element.new 'link'
      link << url
      item << link
    end

    if id = rss_field_for(object, model, params, :guid)
      guid = Ox::Element.new 'guid'
      guid[:isPermaLink] = "false"
      guid << id
      item << guid
    end

    if date = rss_field_for(object, model, params, :pubDate)
      pubdate = Ox::Element.new 'pubDate'
      if !date.is_a?(Time)
        date = Time.zone.parse(date)
      end
      pubdate << date.rfc2822
      item << pubdate
    end

    item
  end

  # wildly unstandardized JSON RSS model
  def jss(results, models, params)
    # only work for models that have been configured for RSS
    model = models.is_a?(Array) ? models.first : models
    halt 404 unless model.rss

    results['@channel'] = {
      'title' => "Sunlight Congress API Results",
      'description' => "Customized RSS results for the people and work of Congress, by the Sunlight Foundation.",
      'link' => "https://sunlightlabs.github.io/congress",
      'items' => 'results'
    }

    results[:results].each do |result|
      result['@item'] = jss_item result, model, params
    end

    json results
  end

  def jss_item(object, model, params)
    item = {}

    if t = rss_field_for(object, model, params, :title)
      item['title'] = t
    end

    if desc = rss_field_for(object, model, params, :description)
      item['description'] = desc
    end

    if url = rss_field_for(object, model, params, :link)
      item['link'] = url
    end

    if id = rss_field_for(object, model, params, :guid)
      item['guid'] = id
    end

    if date = rss_field_for(object, model, params, :pubDate)
      if !date.is_a?(Time)
        date = Time.zone.parse(date).utc
      end
      item['pubDate'] = date
    end

    item
  end


  # get the right value for a given RSS field

  def rss_field_for(object, model, params, field)
    mapped = params["rss.#{field}"] || model.rss[field]
    return nil unless mapped

    levels = mapped.split "."
    rss_field_from object, levels
  end

  # recursive object parsing, don't bother with arrays
  def rss_field_from(object, levels)
    # we should never see an array
    return nil if object.is_a?(Array)

    # base case, we're done
    if levels.size == 0
      # we didn't get to the bottom
      if object.is_a?(Hash)
        nil
      else
        object
      end

    # go one level down
    else
      return nil unless next_level = levels.first
      rss_field_from object[next_level], levels[1..-1]
    end
  end

end