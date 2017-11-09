Pod::Spec.new do |s|

  s.name         = "Kinieta"
  s.version      = "0.5.1"
  s.summary      = "An Animation Engine for iOS with an Intuitive API and Readable Code!."

  s.description  = <<-DESC
 I decided to build an Animation Engine from scratch for the usual reason: No other did what I wanted how I wanted it! While there are some great libraries out there, my requiremenets where pretty restrictive as what I wanted was:
1. A library written in Swift 4.0
2. With a timeline approach where animations can run in parallel at different start and end points
3. The ability to group various animations from different views with a single complete block
4. A simple API where I could just throw in some variables and the rest would be dealt by the library
5. A convention over configuration approach where many variables would be assumed when not passed
6. Efficient interpolation with infinite easing functions based on custom Bezier curves
7. Provides real color interpolation using the advanced HCL color space rather than plain RGB
8. Code that was extremely easy to read and new developers from the community could join in in no time!
                   DESC

  s.homepage     = "https://github.com/mmick66/kinieta"

  s.license      = { :type => "MIT", :file => "LICENSE" }

  s.author       = "Michael Michailidis"

  s.platform     = :ios, "9.0"

  s.source       = { :git => "https://github.com/mmick66/kinieta.git", :tag => s.version }

  s.source_files = "Kinieta/*.{swift}"

end