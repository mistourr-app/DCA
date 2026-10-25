components {
  id: "sprite"
  component: "/game_objects/cell_sprite.sprite"
}
components {
  id: "label"
  component: "/game_objects/cell_label.label"
  position {
    z: 0.2
  }
}
components {
  id: "card"
  component: "/game_objects/card.script"
  properties {
    id: "lift_scale"
    value: "1.25"
    type: PROPERTY_TYPE_NUMBER
  }
  properties {
    id: "lunge_ms"
    value: "150.0"
    type: PROPERTY_TYPE_NUMBER
  }
  properties {
    id: "fall_ms"
    value: "600.0"
    type: PROPERTY_TYPE_NUMBER
  }
  properties {
    id: "flash_ms"
    value: "100.0"
    type: PROPERTY_TYPE_NUMBER
  }
  properties {
    id: "flash_color"
    value: "1.0, 1.0, 1.0, 1.0"
    type: PROPERTY_TYPE_VECTOR4
  }
}
