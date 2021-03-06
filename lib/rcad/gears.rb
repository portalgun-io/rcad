# calculations based on:
# * http://makezine.com/2010/06/28/make-your-own-gears/
#   based in turn on http://www.bostongear.com/pdf/gear_theory.pdf
#   (can be found in Wayback Machine)
# * http://en.wikipedia.org/wiki/Gear
# * http://www.metrication.com/engineering/gears.html


require 'rcad'


class GearProfile < Shape
  attr_reader :pitch_dia, :module_, :p_angle

  # pitch_dia - effective diameter of gear
  #   (not the same as outer diameter)
  # module_ - ratio of pitch diameter to number of teeth (basically the
  #   arc length of the tooth spacing)
  # p_angle - pressure angle.
  #   it seems 20 deg angle is better for torque, but
  #   14.5 deg angle is better for backlash.
  def initialize(opts)
    # TODO: allow specifying different combinations of options, and calculate
      # the rest from those specified

    # converting everything to floats ensures that floating point
    # division will be performed later
    @pitch_dia = opts.fetch(:pitch_dia).to_f
    @module_ = (opts[:module] || 4).to_f
    @p_angle = (opts[:p_angle] || 20).to_f

    if @pitch_dia % @module_ != 0
      raise ArgumentError, "non-integer number of teeth!"
    end
  end

  def num_teeth
    (pitch_dia / module_).to_int
  end

  def diametrical_pitch
    1.0 / module_
  end

  def circular_pitch
    Math::PI / diametrical_pitch
  end

  def addendum
    1.0 / diametrical_pitch
  end

  def outer_dia
    pitch_dia + 2.0 * addendum
  end

  def whole_depth
    module_ < 1.25 ? (2.4 * module_) : (2.25 * module_)
  end

  def dedendum
    whole_depth - addendum
  end

  def root_dia
    pitch_dia - 2 * dedendum
  end

  # tooth thickness at pitch dia
  def tooth_thickness
    Math::PI / 2.0 / diametrical_pitch
  end

  def render
    # tooth thickness at tooth tip (TODO: is this correct?)
    tooth_tip_thickness = tooth_thickness - addendum * Math.sin(p_angle)

    # half of thickness at root/center/tip in degrees
    half_t_root_angle = Math.atan(tooth_thickness / 2 / (root_dia / 2))
    half_t_angle = Math.atan(tooth_thickness / 2 / (pitch_dia / 2))
    half_t_tip_angle = Math.atan(tooth_tip_thickness / 2 / (outer_dia / 2))

    root_r = root_dia / 2
    pitch_r = pitch_dia / 2
    outer_r = outer_dia / 2

    points = []
    (1..num_teeth).each do |i|
      angle = (2 * Math::PI / num_teeth) * i
      points << to_polar(root_r, angle - half_t_root_angle)
      points << to_polar(pitch_r, angle - half_t_angle)
      points << to_polar(outer_r, angle - half_t_tip_angle)
      points << to_polar(outer_r, angle + half_t_tip_angle)
      points << to_polar(pitch_r, angle + half_t_angle)
      points << to_polar(root_r, angle + half_t_root_angle)
    end

    polygon(points)
  end
end


class SpurGear < Shape
  attr_reader :height, :profile

  def initialize(opts)
    @height = opts.fetch(:h)

    profile_opts = opts
    profile_opts.delete(:h)

    @profile = GearProfile.new(profile_opts)

    @shape = profile.extrude(height)
  end
end


class HelicalGear < Shape
  attr_reader :height, :helix_angle, :profile

  def initialize(opts)
    @height = opts.fetch(:h)
    @helix_angle = opts[:helix_angle] || (Math::PI / 3.0)

    profile_opts = opts.dup
    profile_opts.delete(:h)
    profile_opts.delete(:helix_angle)

    @profile = GearProfile.new(profile_opts)

    @shape = profile.extrude(height, twist)
  end

  def twist
    twist_length = Math.tan(helix_angle) * height
    pitch_circumference = Math::PI * profile.pitch_dia

    twist_length * (2 * Math::PI / pitch_circumference)
  end
end


class HerringboneGear < Shape
  attr_reader :height

  def initialize(opts)
    @height = opts.fetch(:h)

    @shape = add do
        helical_opts = opts.dup
        helical_opts[:h] = height / 2.0
        bottom_half = ~HelicalGear.new(helical_opts)

        # make top half's helix twist backwards from where bottom half's
        # twist ends
        helical_opts[:helix_angle] = -bottom_half.helix_angle
        top_half = ~HelicalGear.new(helical_opts)
          .move_z(height / 2.0)
          .rot_z(bottom_half.twist)
      end
  end
end
