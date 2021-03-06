require 'point'

#The uWave recognizer was the second recognizer implemented for CAGE. It was developed by Rice University.
#More information about uWave is available at: htttp://www.ruf.rice.edu/~mobile/publications/liu08uwave.pdf
#This module is specifically designed for accelerometers, and is also designed to be computationally simple.
# In order to covnvert a set of points into a gesture, call "points_to_gesture(points)"
# This will return a set of "resampled" points that have been converted by uWave.
# To compare a gesture to a set of other gestures, where all sets of points have been run through points_to_gesture,
# call "recognize(points[], templates[])"
#
# Author:: Michael O'Keefe

module Uwave

  QUAN_WIN_SIZE = 4
  QUAN_MOV_STEP = 1
  INFINITY = 2**30 #or a reasonable approximation thereof

  #This method takes a set of points and compares them against each set of points in the array of points in "templates".
  #It returns the closest matching gesture in templates[], and the match score for that gesture.
  def recognize(points, templates)
    distances = Array.new
    templates.each_index do |i|
      $table = Array.new(templates[i].num_points * points.length, -1.0)
      distances[i] = 1.0 * DTW_distance(points, points.length, templates[i].resampled_points, templates[i].num_points, points.length-1, templates[i].num_points-1)
      distances[i] = (distances[i] / (points.length + templates[i].num_points))
    end
    ret = 0.0
    distances.each_index do |j|
      if (distances[j] < distances[ret])
        ret = j
      end
    end

    return templates[ret], distances[ret]
  end

  #This is a wrapper function which starts converting a set of points into a set of resampled points for a gesture by calling "quantize_acc(points, points.length)"
  def points_to_gesture(points)
    points = quantize_acc(points, points.length)
    return points
  end

  #This function quantizes the acceleration from -16..16, in integer steps.
  def quantize_acc(points, length)
    i = 0
    k = 0
    window = QUAN_WIN_SIZE
    temp = Array.new(length/QUAN_MOV_STEP + 1)
    acc_data = Array.new
    temp_point_vals = Array.new(3)
    while i < length
        window = length - i if (i + window) > length #if
        for l in 0..2
            sum = 0
            for j in i...(window + i)
                sum = sum + points[j].int_array[l]
            end #for j
            temp_point_vals[l] = ((sum * 1.0)/window)
        end #for l
        temp[k] = Point.new(temp_point_vals[0], temp_point_vals[1], temp_point_vals[2])
        k = k + 1
        i = i + QUAN_MOV_STEP
    end #while

    #nonlinear quantization
    for i in 0...k
      temp_array = Array.new
      for l in 0..2
        temp_array[l] = case temp[i].int_array[l]
          when 80..128 then 16
          when 40...80 then 10 + (temp[i].int_array[l]-10)/10*5
          when -20...-10 then -10 + (temp[i].int_array[l] + 10)/10*5
          when -128...-80 then -16
          when -40...40 then temp[i].int_array[l] / 4
          else 0
        end
      end
      acc_data[i] = Point.new(temp_array[0], temp_array[1], temp_array[2])
    end
    return acc_data
  end

  #This function computes the "Dynamic Time Warping" distance between 2 samples of points recursively, using dynamic programming.
  #input: int[], int, int[], int, int, int, int[]
  def DTW_distance(sample1, length1, sample2, length2, i, j)
    s_distance = 0.0
    if (i < 0 || j < 0)
      return INFINITY
    end
    table_width = length2
    local_distance = 0
    for k in 0..2
      local_distance = local_distance + ((sample1[i].int_array[k]-sample2[j].int_array[k])*(sample1[i].int_array[k]-sample2[j].int_array[k]))
    end
    if ((i == 0) && (j == 0))
      if ($table[i*table_width+j] < 0)
        $table[i*table_width+j] = local_distance
      end
      return local_distance
    elsif (i == 0)
      if ($table[i*table_width+j] < 0)
        s_distance = DTW_distance(sample1, length1, sample2, length2, i-1, j)
      else
        s_distance = $table[$table[i*table_width+j-1]]
      end
    elsif (j == 0)
      if ($table[(i-1)*table_width+j] < 0)
        s_distance = DTW_distance(sample1, length1, sample2, length2, i, j-1)
      else
        s_distance = $table[i*table_width+j-1]
      end
    else
      if ($table[i*table_width+j-1] < 0)
        s1 = DTW_distance(sample1, length1, sample2, length2, i, j-1)
      else
        s1 = $table[i*table_width+j-1]
      end
      if ($table[(i-1)*table_width+j] < 0)
        s2 = DTW_distance(sample1, length1, sample2, length2, i-1, j)
      else
        s2 = $table[(i-1)*table_width+j]
      end
      if ($table[(i-1)*table_width+j-1] < 0)
        s3 = DTW_distance(sample1, length1, sample2, length2, i-1, j-1)
      else
        s3 = $table[(i-1)*table_width+j-1]
      end
      s_distance = s1 < s2 ? s1 : s2
      s_distance = s_distance < s3 ? s_distance : s3
    end

    $table[i*table_width+j] = (local_distance + s_distance)
    return $table[i*table_width+j]
  end

end
