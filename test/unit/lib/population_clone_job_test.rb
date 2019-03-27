require 'test_helper'
require 'fileutils'

class PopulationCloneJobTest < ActiveSupport::TestCase
  def setup
    @pt = FactoryBot.create(:product_test_static_result)
    @pt.save!
  end

  def test_perform_full_deck
    pcj = Cypress::PopulationCloneJob.new('test_id' => @pt.id)
    pcj.perform
    assert_equal 19, Patient.count
    assert_equal 10, Patient.where(correlation_id: @pt.id).count
  end

  def test_assigns_default_provider
    # ids passed in should clone just the 1 record
    sample_patient = @pt.bundle.patients.sample
    @pt.provider = Provider.default_provider
    @pt.save!
    pcj = Cypress::PopulationCloneJob.new('patient_ids' => [sample_patient.id],
                                          'test_id' => @pt.id,
                                          'randomization_ids' => [])
    pcj.perform
    prov = Provider.where(default: true).first
    assert_equal 11, Patient.count
    patients_with_provider = Patient.where(correlation_id: @pt.id, provider_performances: { :$exists => true })
    assert_equal 1, patients_with_provider.keep_if { |pt| pt.provider.id == prov.id }.size
  end

  def test_shifts_dates_no_shift
    # Setup test data for non-date-shifting patients
    patient1_no_shift = Patient.all[0].clone
    patient2_no_shift = Patient.all[1].clone
    # Add 1 month to birthDatetime so that it is not sitting on a year boundry
    # this is so that the randomization won't cross the year boundry to make assertions consistent
    patient1_no_shift.qdmPatient.birthDatetime += 1.month
    patient2_no_shift.qdmPatient.birthDatetime += 1.month
    patient1_no_shift.save
    patient2_no_shift.save
    # Build and perform the date-shifting and non-date-shifting PopulationCloneJobs
    pcj1 = Cypress::PopulationCloneJob.new('patient_ids' => [patient1_no_shift.id.to_s], 'test_id' => @pt.id.to_s,
                                           'randomization_ids' => [patient2_no_shift.id.to_s])
    patients = pcj1.perform

    # Get the patients that resulted from the cloning in the PopulationCloneJobs
    patient1_no_shift_clone = patients.select { |patient| patient.original_patient_id == patient1_no_shift.id }.first
    patient2_randomized_no_shift_clone = patients.select { |patient| patient.original_patient_id == patient2_no_shift.id }.first

    # assert patient1_no_shift_clone has not been shifted
    assert_equal patient1_no_shift_clone.qdmPatient.birthDatetime, patient1_no_shift_clone.qdmPatient.birthDatetime
    # assert patient2_randomized_no_shift_clone has not been shifted
    assert_equal Time.zone.at(patient2_randomized_no_shift_clone.qdmPatient.birthDatetime).year, Time.zone.at(patient2_no_shift.qdmPatient.birthDatetime).year
    # assert patient2_no_shift_clone has been randomized
    assert_not_equal Time.zone.at(patient2_randomized_no_shift_clone.qdmPatient.birthDatetime).day, Time.zone.at(patient2_no_shift.qdmPatient.birthDatetime).day
    # assert patient2_randomized_shift_clone randomized
    assert_not_equal Time.zone.at(patient2_randomized_no_shift_clone.qdmPatient.birthDatetime).day, Time.zone.at(patient2_no_shift.qdmPatient.birthDatetime).day
  end

  def test_shifts_dates_with_shift
    # Setup test data for date-shifting patients
    pt2 = @pt.clone
    pt2.product.shift_patients = true
    pt2.save!
    patient1_shift = Patient.all[0].clone
    patient2_shift = Patient.all[1].clone
    # Add 1 month to birthDatetime so that it is not sitting on a year boundry
    # this is so that the randomization won't cross the year boundry to make assertions consistent
    patient1_shift.qdmPatient.birthDatetime += 1.month
    patient2_shift.qdmPatient.birthDatetime += 1.month
    patient1_shift.save
    patient2_shift.save
    pcj2 = Cypress::PopulationCloneJob.new('patient_ids' => [patient1_shift.id.to_s], 'test_id' => pt2.id,
                                           'randomization_ids' => [patient2_shift.id.to_s])
    patients = pcj2.perform
    # Get the patients that resulted from the cloning in the PopulationCloneJobs
    patient1_shift_clone = patients.select { |patient| patient.original_patient_id == patient1_shift.id }.first
    patient2_randomized_shift_clone = patients.select { |patient| patient.original_patient_id == patient2_shift.id }.first

    # assert patient1_shift_clone has been shifted by 2 years which is the offset in the bundle associated with the product test
    assert_equal Time.zone.at(patient1_shift_clone.qdmPatient.birthDatetime).year, Time.zone.at(patient1_shift.qdmPatient.birthDatetime).year + 2
    # assert patient2_randomized_shift_clone has shifted by 2 years which is the offset in the bundle associated with the product test
    assert_equal Time.zone.at(patient2_randomized_shift_clone.qdmPatient.birthDatetime).year, Time.zone.at(patient2_shift.qdmPatient.birthDatetime).year + 2
    # assert patient2_randomized_shift_clone randomized
    assert_not_equal Time.zone.at(patient2_randomized_shift_clone.qdmPatient.birthDatetime).day, Time.zone.at(patient2_shift.qdmPatient.birthDatetime).day
  end

  def test_perform_reconnect_reference
    # Add an element with a reference to the first patient in the product test
    patient_with_ref = @pt.bundle.patients.first
    comm_with_ref = QDM::CommunicationPerformed.new(dataElementCodes: [QDM::Code.new('336', '2.16.840.1.113883.6.96')])
    comm_with_ref.relatedTo << patient_with_ref.qdmPatient.dataElements[0].id
    patient_with_ref.qdmPatient.dataElements << comm_with_ref
    patient_with_ref.save
    pcj = Cypress::PopulationCloneJob.new('subset_id' => 'all',
                                          'test_id' => @pt.id,
                                          'patient_ids' => [patient_with_ref.id],
                                          'randomize_demographics' => true)
    pcj.perform
    new_record_with_ref = Patient.where(correlation_id: @pt.id, original_patient_id: patient_with_ref.id).first
    new_ref = new_record_with_ref.qdmPatient.communications.first.relatedTo.first.value
    original_ref = patient_with_ref.qdmPatient.communications.first.relatedTo.first.value
    assert_not_equal new_ref, original_ref
  end

  def test_perform_randomized_races
    # Clone and ensure they have random races
    pcj = Cypress::PopulationCloneJob.new('subset_id' => 'all',
                                          'test_id' => @pt.id,
                                          'randomize_demographics' => true)
    pcj.perform
    new_records = Patient.where(correlation_id: @pt.id)
    assert_equal 10, new_records.count
    assert_races_are_random
  end

  def test_perform_replace_other_race
    # Clone and ensure that "Other" is always replaced with the same code '2106-3'
    pcj = Cypress::PopulationCloneJob.new('randomize_demographics' => false)
    prng = Random.new(@pt.rand_seed.to_i)
    patient = Patient.first
    # Replace original race code with the code for 'Other'
    patient.qdmPatient.get_data_elements('patient_characteristic', 'race').first.dataElementCodes.first['code'] = '2131-1'
    pcj.clone_and_save_patient(patient, prng, Provider.first)
    cloned_patient = Patient.where(original_patient_id: patient.id).first
    # Assert that the new race is consistent '2106-3'
    assert_equal '2106-3', cloned_patient.race
  end

  def assert_races_are_random
    found_random = false
    old_record_races = {}
    Patient.where(correlation_id: nil).each do |record|
      old_record_races["#{record.givenNames[0]} #{record.familyName}"] = record.race
    end
    Patient.where(correlation_id: @pt.id).each do |record|
      found_random = true unless old_record_races["#{record.givenNames[0]} #{record.familyName}"] == record.race
    end
    assert found_random, 'Did not find any evidence that race was randomized.'
  end

  def clone_records(product_test, options = {})
    options['test_id'] = product_test.id unless options['test_id']
    options['subset_id'] = 'all'
    options['randomize_demographics'] = true
    pcj = Cypress::PopulationCloneJob.new(options.stringify_keys!)
    pcj.perform
    Record.where(test_id: product_test.id)
  end
end
