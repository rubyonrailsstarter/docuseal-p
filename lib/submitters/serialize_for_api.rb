# frozen_string_literal: true

module Submitters
  module SerializeForApi
    SERIALIZE_PARAMS = {
      only: %i[id slug uuid name email phone completed_at declined_at external_id
               submission_id metadata opened_at sent_at created_at updated_at],
      methods: %i[status application_key]
    }.freeze

    module_function

    def call(submitter, with_template: false, with_events: false, with_documents: true, with_urls: false, params: {})
      ActiveRecord::Associations::Preloader.new(
        records: [submitter],
        associations: if with_documents
                        [documents_attachments: :blob, attachments_attachments: :blob]
                      else
                        [attachments_attachments: :blob]
                      end
      ).call

      additional_attrs = {}

      if params[:include].to_s.include?('fields')
        additional_attrs['fields'] = SerializeForWebhook.build_fields_array(submitter)
      end

      additional_attrs['values'] = SerializeForWebhook.build_values_array(submitter)
      additional_attrs['documents'] = SerializeForWebhook.build_documents_array(submitter) if with_documents
      additional_attrs['preferences'] = submitter.preferences.except('default_values')
      additional_attrs['submission_events'] = serialize_events(submitter.submission_events) if with_events

      additional_attrs['role'] =
        (submitter.submission.template_submitters ||
         submitter.submission.template.submitters).find { |e| e['uuid'] == submitter.uuid }['name']

      if with_urls
        additional_attrs['embed_src'] =
          Rails.application.routes.url_helpers.submit_form_url(slug: submitter.slug, **Docuseal.default_url_options)
      end

      include_params = {}
      include_params[:template] = { only: %i[id name created_at updated_at] } if with_template

      submitter.as_json(SERIALIZE_PARAMS.merge(include: include_params)).merge(additional_attrs)
    end

    def serialize_events(events)
      events.map do |event|
        event.as_json(only: %i[id submitter_id event_type event_timestamp]).merge('data' => event.data.slice('reason'))
      end
    end
  end
end
