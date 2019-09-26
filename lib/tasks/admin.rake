namespace :cypress do
  task :setup => :environment

  desc %(
    Add an admin user
  )
  task :create_admin, %i[email password] => :setup do |_, args|
    user = User.where(:email => args.email).first
    if user
      puts %( A user with the email address #{args.email} already existis in the system.
      Please use the cypress:add_admin rake command to add the admin role to this user.)
    else
      password = args.password
      if password.blank?
        puts 'Password cannot be blank.  Please provide a password for the new administrator account'
      else
        u = User.new(:email => args.email, :password => args.password, :password_confirmation => args.password, :terms_and_conditions => '1')
        if u.save
          u.add_role :admin
          puts "Created admin user with email  #{args.email}"
        else
          puts u.errors.full_messages
        end
      end
    end
  end
  desc %(
    Add the admin role to an existing user
  )
  task :add_admin, [:email] => :setup do |_, args|
    user = User.where(:email => args.email).first
    if user
      user.update(:approved => true)
      user.add_role :admin
      puts "Added admin role to user #{args.email}"
    else
      puts %( User #{args.email} not found in the system.  Please check the email address or to create an admin user with that
      email address use the cypress:create_admin rake command)
    end
  end

  desc %(
    Remove the admin role from an existing user
  )
  task :remove_admin, [:email] => :setup do |_, args|
    user = User.where(:email => args.email).first
    if user
      user.remove_role :admin
      puts "removed admin role from user #{args.email}"
    else
      puts "User #{args.email} not found "
    end
  end

  desc %(
    Upload measure bundle file with extension .zip
  )
  task :upload_bundle, [:file] => :setup do |_, args|
    bundle_file = args.file
    bundle_name = bundle_file.split("/").last()
    unless File.extname(bundle_name) == '.zip'
      puts 'Bundle file must have extension .zip'
      return
    end

    FileUtils.mkdir_p(APP_CONSTANTS['bundle_file_path'])
    file_name = "bundle_#{rand(Time.now.to_i)}.zip"
    file_path = File.join(APP_CONSTANTS['bundle_file_path'], file_name)
    FileUtils.mv(bundle_file, file_path)
    BundleUploadJob.perform_later(file_path, bundle_name)
    puts "Uploading #{bundle_name} bundle"
  end

end
