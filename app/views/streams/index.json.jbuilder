json.array! @streams do |stream|
  json.id stream.public_id
  json.lat stream.lat
  json.lng stream.lng
  json.user do
    json.device_uuid stream.user.device_uuid
  end
  json.active stream.active
end
