namespace :patients do
  task setup: :environment

  task find_dx: :setup do
    all_vs = {}
    CSV.open("script/patient_dx_all.csv", "w") do |csv|
      BundlePatient.each do |bp|
        bp_condition_vs = []
        en_encounter_dx = []
        bp.qdmPatient.conditions.each do |c|
          c['dataElementCodes'].each do |dec|
            # check if snomed
            next unless dec['codeSystemOid'] == '2.16.840.1.113883.6.96'
            ValueSet.where('concepts.code' => dec['code']).each do |vs|
              #csv << ["#{bp.givenNames[0]} #{bp.familyName}", dec['code'], vs.oid, 'Condition']
              bp_condition_vs << vs.oid
            end
          end
        end
        bp.qdmPatient.get_data_elements('encounter', 'performed').each do |c|
          if c.principalDiagnosis && c.principalDiagnosis.codeSystemOid == '2.16.840.1.113883.6.96'
            ValueSet.where('concepts.code' => c.principalDiagnosis.code).each do |vs|
              #csv << ["#{bp.givenNames[0]} #{bp.familyName}", c.principalDiagnosis.code, vs.oid, 'principalDiagnosis']
              en_encounter_dx << vs.oid
            end
          end
          c.diagnoses&.each do |encounter_diagnosis|
            next unless encounter_diagnosis.codeSystemOid == '2.16.840.1.113883.6.96'
            ValueSet.where('concepts.code' => encounter_diagnosis.code).each do |vs|
              #csv << ["#{bp.givenNames[0]} #{bp.familyName}", encounter_diagnosis.code, vs.oid, 'encounter_diagnosis']
              en_encounter_dx << vs.oid
            end
          end
        end
        bp_condition_vs.uniq!
        en_encounter_dx.uniq!
        [en_encounter_dx - bp_condition_vs].each do |missing_dx_vs|
          missing_dx_vs.each do |missing_vs|
            all_vs[missing_vs] = [] unless all_vs[missing_vs]
            #all_vs[missing_vs] << "#{bp.givenNames[0]} #{bp.familyName}"
            all_vs[missing_vs] << bp.id
          end
        end
      end
      Measure.each do |mes|
        mes.source_data_criteria.each do |criteria|
          next unless criteria._type.eql? 'QDM::Diagnosis'
          unless all_vs[criteria.codeListId].nil?
            all_vs[criteria.codeListId].each do |bp_name|
              patient = Patient.find(bp_name)
              #next unless patient.measure_relevance_hash[mes.id.to_s]
              #next unless patient.measure_relevance_hash[mes.id.to_s]['IPP'] == true
              csv << [mes.cms_id, criteria.codeListId, "#{patient.givenNames[0]} #{patient.familyName}"]
            end
          end
        end
      end
    end
  end
end
    