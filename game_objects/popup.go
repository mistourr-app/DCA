components {
  id: "label"
  component: "/game_objects/cell_label.label"
}
components {
  id: "popup"
  component: "/game_objects/popup.script"
  properties {
    id: "float_ms"
    value: "600.0"
    type: PROPERTY_TYPE_NUMBER
  }
  properties {
    id: "float_rise"
    value: "60.0"
    type: PROPERTY_TYPE_NUMBER
  }
  properties {
    id: "color_damage"
    value: "1.0, 0.122, 0.122, 1.0"
    type: PROPERTY_TYPE_VECTOR4
  }
  properties {
    id: "color_heal"
    value: "0.063, 0.725, 0.506, 1.0"
    type: PROPERTY_TYPE_VECTOR4
  }
  properties {
    id: "color_gold"
    value: "1.0, 0.906, 0.38, 1.0"
    type: PROPERTY_TYPE_VECTOR4
  }
}
