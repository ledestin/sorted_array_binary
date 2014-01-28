# Automatically sorted array (by using binary search). Nils aren't allowed.
#
# = Example
#   require 'sorted_array_binary'
#
#   # Use standard sorting via <=>.
#   array = SortedArrayBinary.new
#   array.push 'b', 'a' #=> ['a', 'b']
#
#   # Use custom sorting block.
#   array = SortedArrayBinary.new { |a, b| b <=> a }
#   array.push 'a', 'b' #=> ['b', 'a']
class SortedArrayBinary < Array
  # Readable names for values returned by <=>.
  ELEMENT_COMPARE_STATES = { -1 => :less, 0 => :equal, 1 => :greater }

  class InvalidSortBlock < RuntimeError #:nodoc:
  end

  def self._check_for_nil *objs #:nodoc:
    raise ArgumentError, "nils aren't allowed into sorted array" \
      if objs.include?(nil)
  end

  alias :old_insert :insert
  private :old_insert
  alias :old_sort! :sort!
  private :old_sort!

  def initialize *args, &b
    # Passed sort block.
    if args.size == 0 && block_given?
      @sort_block = b
      super()
      return
    end

    if args.size == 1
      # Passed initial array.
      if args.first.respond_to? :each
	self.class._check_for_nil *args.first
	super *args
	old_sort!
	return
      end

      # Passed size and block.
      if block_given?
	super *args, &b
	self.class._check_for_nil *self
	old_sort!
	return
      end

      # Passed size, but not obj, which means fill with nils.
      raise ArgumentError, "can't fill array with nils" \
	if args.first.is_a? Numeric
    end

    super
  end

  # Not implemented methods.
  #
  # The following methods are not implemented mostly because they change order
  # of elements. The rest ([]= and fill) arguably aren't useful on a sorted
  # array.
  def _not_implemented *args #:nodoc:
    raise NotImplementedError
  end

  [:[]=, :fill, :insert, :reverse!, :rotate!, :shuffle!, :sort!, :unshift].
  each { |m|
    alias_method m, :_not_implemented
  }

  # Same as Array#collect!, but:
  # * Disallow nils in the resulting array.
  # * The resulting array is sorted.
  def collect! &b
    replace(collect &b)
  end
  alias :map! :collect!

  # Same as Array#concat, but:
  # * Disallow nils in the passed array.
  # * The resulting array is sorted.
  def concat other_ary
    _add *other_ary
  end

  # Same as Array#flatten!, but:
  # * Disallow nils in the resulting array.
  # * The resulting array is sorted.
  def flatten! *args
    replace(flatten *args)
  end

  # Add objects to array, automatically placing them according to sort order.
  # Disallow nils.
  def push *objs
    _add *objs
  end
  alias :<< :push

  # Same as Array#replace, but:
  # * Disallow nils in @other_ary.
  # * The resulting array is sorted.
  def replace other_ary
    self.class._check_for_nil *other_ary
    super
    old_sort!
    self
  end

  #private
  # Name the following methods starting with underscore so as not to pollute
  # Array namespace. They are considered private, but for testing purposes are
  # left public.

  def _add *objs #:nodoc:
    self.class._check_for_nil *objs
    objs.each { |obj|
      old_insert _find_insert_position(obj), obj
    }
    self
  end

  def _check_can_calc_boundary? #:nodoc:
    raise "can't calc boundary on empty array" if empty?
  end

  def _compare a, b #:nodoc:
    state = ELEMENT_COMPARE_STATES[@sort_block ?
      @sort_block.call(a, b) : a <=> b]
    raise InvalidSortBlock,
      "sort block returned invalid value: #{state.inspect}" unless state
    state
  end

  def _find_insert_position arg #:nodoc:
    return 0 if empty?

    # At this point, there must be >1 elements in the array.
    start, ending = 0, size - 1
    loop {
      middle_idx = _middle_element_index(start, ending)
      middle_el = self[middle_idx]
      after_middle_idx = middle_idx + 1

      comparison_state = _compare(arg, middle_el)

      # 1. Equals to the middle element. Insert after el.
      return after_middle_idx if comparison_state == :equal

      # 2. Less than the middle element.
      if comparison_state == :less
	# There's nothing to the left. So insert it as the first element.
	return 0 if _left_boundary? middle_idx

	ending = middle_idx
	next
      end

      # 3. Greater than the middle element.
      #
      # Right boundary? Put arg after the last (middle) element.
      return after_middle_idx if _right_boundary? middle_idx

      # Less than after middle element? Put it right before it!
      after_middle_el = self[after_middle_idx]
      ret = _compare(arg, after_middle_el)
      return after_middle_idx if ret == :equal || ret == :less

      # Proceeed to divide the right part.
      start = after_middle_idx
    }
  end

  def _left_boundary? idx #:nodoc:
    _check_can_calc_boundary?
    idx == 0
  end

  def _middle_element_index start, ending #:nodoc:
    start + (ending - start)/2
  end

  def _right_boundary? idx #:nodoc:
    _check_can_calc_boundary?
    idx == size - 1
  end
end
