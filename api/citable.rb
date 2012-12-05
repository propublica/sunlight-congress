module Citable
  def self.add_to(models, documents, params)
    models = [models] unless models.is_a?(Array)

    # must explicitly ask for extra information and performance hit
    return documents unless params["citing.details"].present?

    # only citation-enabled models
    return documents unless params[:citing].present? and models.select {|model| model.cite_key.nil?}.empty?

    criteria = {}

    citation_ids = params[:citing].split "|"
    if citation_ids.size > 1
      criteria.merge! citation_id: {"$in" => citation_ids}
    else
      criteria.merge! citation_id: citation_ids.first
    end

    if models.size > 1
      criteria.merge! document_type: {"$in" => models.map(&:to_s)}
    else
      criteria.merge! document_type: models.first.to_s
    end

    documents.map do |document|
      if models.size > 1
        model = document[:search][:type].camelize.constantize
      else
        model = models.first
      end

      matches = Citation.where(
        criteria.merge(
          document_id: document[model.cite_key.to_s]
        )
      )
      
      if matches.any?
        citations = []
        matches.each do |match|
          citations += match['citations']
        end
        document['citations'] = citations
      end

      document
    end
  end
end