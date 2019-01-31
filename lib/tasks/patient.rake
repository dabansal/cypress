
namespace :cypress do
  namespace :patient do

    def measure_selector
      "/cda:ClinicalDocument/cda:component/cda:structuredBody/cda:component/cda:section/cda:entry" +
      "/cda:organizer[./cda:templateId[@root='2.16.840.1.113883.10.20.24.3.98']]/cda:reference[@typeCode='REFR']" +
          "/cda:externalDocument[@classCode='DOC']/cda:id[@root='2.16.840.1.113883.4.738']/@extension"
    end

    desc 'Generate HTML for an uploaded QRDA document'
    task :generate_html, [:qrda_file] => :environment do |_t, args|
      Mongoid.load!('config/mongoid.yml', :development)
      print 'Importing File...'
      doc = File.open(args.qrda_file) { |f| Nokogiri::XML(f) }
      doc.root.add_namespace_definition('cda', 'urn:hl7-org:v3')
      doc.root.add_namespace_definition('sdtc', 'urn:hl7-org:sdtc')
      patient = QRDA::Cat1::PatientImporter.instance.parse_cat1(doc)
      patient.save
      output = File.open("#{args.qrda_file}.html", 'w')
       output << QdmPatient.new(patient, true).render.html_safe
      output.close

      doc_start_time = doc.at_xpath("/cda:ClinicalDocument/cda:component/cda:structuredBody/cda:component/cda:section/
              cda:entry/cda:act[./cda:templateId[@root='2.16.840.1.113883.10.20.17.3.8']]/
              cda:effectiveTime/cda:low/@value")

      doc_end_time = doc.at_xpath("/cda:ClinicalDocument/cda:component/cda:structuredBody/cda:component/cda:section/
        cda:entry/cda:act[./cda:templateId[@root='2.16.840.1.113883.10.20.17.3.8']]/
        cda:effectiveTime/cda:high/@value")

      doc.xpath(measure_selector).each do |measure|
        Measure.where(hqmf_id: measure.value.upcase).each do |ecqm|
          bundle = Bundle.find(ecqm.bundle_id)
          value_sets = bundle.value_sets.in(:oid.in => ecqm.oids.flatten.uniq)
          value_set_map = {}
          value_sets.each do |vs|
            value_set_map[vs['oid']] = {} unless value_set_map.key?(vs['oid'])
            value_set_map[vs['oid']][vs['version']] = vs
          end
          value_set_map
          calc_job = Cypress::JsEcqmCalc.new('correlation_id': BSON::ObjectId.new.to_s,
                                             'effective_date': doc_end_time.value)
          results = calc_job.sync_job([patient.id.to_s], [ecqm._id.to_s])
          puts results
        end
      end
    end
  end
end