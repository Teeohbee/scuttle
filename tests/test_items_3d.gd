extends DeckSuite
# In 3D, what a monkey carries is a thing, not a coloured box: a powder keg, a stack of shot, a plank,
# a bucket with or without water. You can tell each apart at a glance, and a bucket fills when it's filled.

const KINDS := [Carryable.Kind.POWDER, Carryable.Kind.SHOT, Carryable.Kind.PLANK,
	Carryable.Kind.BUCKET_WATER, Carryable.Kind.BUCKET_EMPTY]

func _view(deck: Node2D) -> View3D:
	return deck.get_node("View3D")

func _drop(deck: Node2D, kind: Carryable.Kind) -> Carryable:
	var item: Carryable = load("res://src/crew/carryable.tscn").instantiate()
	deck.add_child(item)
	item.global_position = Vector2(200, 100)
	item.set_kind(kind)
	return item

# Every kind's look: its vertex colours, sorted, and the size of what it draws.
func _look(model: ItemModel) -> Array:
	var mesh := model.shown().mesh
	var colors := {}
	for c in mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]:
		colors[c.to_html()] = true
	var keys := colors.keys()
	keys.sort()
	return [keys, mesh.get_aabb().size.snapped(Vector3.ONE * 0.01)]

func test_each_kind_is_its_own_thing_not_a_box() -> void:
	var looks := []
	for kind in KINDS:
		var model: ItemModel = auto_free(ItemModel.new())
		model.show_kind(kind)
		var verts: int = model.shown().mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()
		assert_int(verts).override_failure_message("%s is still a box" % Carryable.Kind.keys()[kind]).is_greater(36)
		var look := _look(model)
		assert_bool(looks.has(look)).override_failure_message("%s looks like another kind" % Carryable.Kind.keys()[kind]).is_false()
		looks.append(look)

func test_each_fits_in_a_monkeys_arms() -> void:
	for kind in KINDS:
		var model: ItemModel = auto_free(ItemModel.new())
		model.show_kind(kind)
		var size := (model.shown().transform * model.shown().get_aabb()).size   # as drawn
		assert_float(maxf(size.x, size.z)).override_failure_message("%s is too big to carry" % Carryable.Kind.keys()[kind]).is_less_equal(1.0)
		assert_float(size.y).is_less_equal(0.6)

func test_the_deck_shows_each_item_as_its_kind() -> void:
	var deck := load_deck()
	_view(deck).set_3d(true, false)
	var items := {}
	for kind in KINDS:
		items[kind] = _drop(deck, kind)
	await drawn_frames(2)
	for kind in KINDS:
		var model := _view(deck).mirror_of(items[kind]) as ItemModel
		assert_object(model).override_failure_message("a carried item is still a box").is_not_null()
		assert_int(model.kind()).is_equal(kind)

func test_a_bucket_fills_in_3d_when_it_fills_in_2d() -> void:
	var deck := load_deck()
	_view(deck).set_3d(true, false)
	var bucket := _drop(deck, Carryable.Kind.BUCKET_EMPTY)
	await drawn_frames(2)
	var model := _view(deck).mirror_of(bucket) as ItemModel
	assert_bool(model.has_water()).is_false()
	bucket.set_kind(Carryable.Kind.BUCKET_WATER)
	await drawn_frames(2)
	assert_bool(model.has_water()).override_failure_message("the bucket stays empty in 3D").is_true()
