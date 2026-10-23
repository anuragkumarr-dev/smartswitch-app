/**
 * @file sw_config_endpoint.c
 * @brief Reference ESP-IDF implementation for SmartSwitch custom provisioning endpoint "sw-config".
 *
 * Implements Blueprint §2.4:
 * 1. Registers the custom endpoint "sw-config" with ESP-IDF wifi_prov_mgr.
 * 2. Unpacks and validates JSON payload:
 *    {
 *      "v": 1,
 *      "mesh": { "id": "<6 bytes hex/binary>", "ap_psk": "<random 16+ chars>", "max_layer": 6 },
 *      "home": { "id": "h_8f21", "net_key_wrapped": "<AES-GCM>", "key_id": 1 },
 *      "activation": { "token": "<signed one-time token>", "cloud": "mqtts://...", "region": "ap-south-1" },
 *      "device": { "name": "Hall switch", "room_id": "r_hall" }
 *    }
 * 3. Persists credentials and configuration into encrypted NVS.
 * 4. Configures ESP-WIFI-MESH parameters.
 */

#include <stdio.h>
#include <string.h>
#include <stdlib.h>

#include "esp_err.h"
#include "esp_log.h"
#include "nvs_flash.h"
#include "nvs.h"
#include "cJSON.h"
#include "wifi_provisioning/manager.h"
#include "esp_wifi.h"
#include "esp_mesh.h"

static const char *TAG = "sw_config_prov";
#define NVS_NAMESPACE "sw_cfg"

/**
 * @brief Helper to create and serialize JSON response buffer for protocomm
 */
static esp_err_t send_json_response(const char *status, const char *message,
                                    uint8_t **outbuf, ssize_t *outlen)
{
    cJSON *root = cJSON_CreateObject();
    if (!root) {
        return ESP_ERR_NO_MEM;
    }

    cJSON_AddStringToObject(root, "status", status);
    if (message) {
        cJSON_AddStringToObject(root, "message", message);
    }

    char *json_str = cJSON_PrintUnformatted(root);
    cJSON_Delete(root);

    if (!json_str) {
        return ESP_ERR_NO_MEM;
    }

    *outlen = strlen(json_str);
    *outbuf = (uint8_t *)json_str; // Caller (protocomm) will free via free()
    return ESP_OK;
}

/**
 * @brief Parses incoming "sw-config" JSON and writes settings to NVS
 */
static esp_err_t parse_and_store_sw_config(const char *json_data)
{
    esp_err_t err = ESP_FAIL;
    cJSON *root = cJSON_Parse(json_data);
    if (!root) {
        ESP_LOGE(TAG, "Failed to parse sw-config JSON");
        return ESP_ERR_INVALID_ARG;
    }

    // 1. Version check
    cJSON *ver_item = cJSON_GetObjectItem(root, "v");
    if (!ver_item || !cJSON_IsNumber(ver_item) || ver_item->valueint != 1) {
        ESP_LOGE(TAG, "Unsupported or missing config version");
        cJSON_Delete(root);
        return ESP_ERR_INVALID_VERSION;
    }

    // 2. Extract nested objects
    cJSON *mesh_obj = cJSON_GetObjectItem(root, "mesh");
    cJSON *home_obj = cJSON_GetObjectItem(root, "home");
    cJSON *act_obj = cJSON_GetObjectItem(root, "activation");
    cJSON *dev_obj = cJSON_GetObjectItem(root, "device");

    if (!mesh_obj || !home_obj || !act_obj || !dev_obj) {
        ESP_LOGE(TAG, "Missing mandatory root sections in sw-config");
        cJSON_Delete(root);
        return ESP_ERR_INVALID_ARG;
    }

    // Mesh fields
    cJSON *mesh_id = cJSON_GetObjectItem(mesh_obj, "id");
    cJSON *mesh_psk = cJSON_GetObjectItem(mesh_obj, "ap_psk");
    cJSON *mesh_layer = cJSON_GetObjectItem(mesh_obj, "max_layer");

    // Home fields
    cJSON *home_id = cJSON_GetObjectItem(home_obj, "id");
    cJSON *home_net_key = cJSON_GetObjectItem(home_obj, "net_key_wrapped");
    cJSON *home_key_id = cJSON_GetObjectItem(home_obj, "key_id");

    // Activation fields
    cJSON *act_token = cJSON_GetObjectItem(act_obj, "token");
    cJSON *act_cloud = cJSON_GetObjectItem(act_obj, "cloud");
    cJSON *act_region = cJSON_GetObjectItem(act_obj, "region");

    // Device fields
    cJSON *dev_name = cJSON_GetObjectItem(dev_obj, "name");
    cJSON *dev_room = cJSON_GetObjectItem(dev_obj, "room_id");

    if (!cJSON_IsString(mesh_id) || !cJSON_IsString(mesh_psk) ||
        !cJSON_IsString(home_id) || !cJSON_IsString(home_net_key) ||
        !cJSON_IsString(act_token) || !cJSON_IsString(act_cloud) ||
        !cJSON_IsString(dev_name) || !cJSON_IsString(dev_room)) {
        ESP_LOGE(TAG, "Invalid string fields in payload");
        cJSON_Delete(root);
        return ESP_ERR_INVALID_ARG;
    }

    // 3. Store into encrypted NVS partition
    nvs_handle_t nvs_handle;
    err = nvs_open(NVS_NAMESPACE, NVS_READWRITE, &nvs_handle);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "Error (%s) opening NVS handle!", esp_err_to_name(err));
        cJSON_Delete(root);
        return err;
    }

    nvs_set_str(nvs_handle, "mesh_id", mesh_id->valuestring);
    nvs_set_str(nvs_handle, "mesh_psk", mesh_psk->valuestring);
    nvs_set_i32(nvs_handle, "mesh_max_layer", mesh_layer ? mesh_layer->valueint : 6);

    nvs_set_str(nvs_handle, "home_id", home_id->valuestring);
    nvs_set_str(nvs_handle, "net_key_wrap", home_net_key->valuestring);
    nvs_set_i32(nvs_handle, "home_key_id", home_key_id ? home_key_id->valueint : 1);

    nvs_set_str(nvs_handle, "act_token", act_token->valuestring);
    nvs_set_str(nvs_handle, "cloud_endpoint", act_cloud->valuestring);
    if (cJSON_IsString(act_region)) {
        nvs_set_str(nvs_handle, "cloud_region", act_region->valuestring);
    }

    nvs_set_str(nvs_handle, "dev_name", dev_name->valuestring);
    nvs_set_str(nvs_handle, "room_id", dev_room->valuestring);

    err = nvs_commit(nvs_handle);
    nvs_close(nvs_handle);

    if (err != ESP_OK) {
        ESP_LOGE(TAG, "NVS commit failed: %s", esp_err_to_name(err));
        cJSON_Delete(root);
        return err;
    }

    ESP_LOGI(TAG, "Successfully persisted sw-config parameters to encrypted NVS");

    // 4. Configure ESP-WIFI-MESH settings (Blueprint §2.4)
    mesh_cfg_t mesh_cfg = MESH_INIT_CONFIG_DEFAULT();
    // Configure mesh AP credentials
    size_t psk_len = strlen(mesh_psk->valuestring);
    if (psk_len > sizeof(mesh_cfg.mesh_ap.password)) {
        psk_len = sizeof(mesh_cfg.mesh_ap.password);
    }
    memcpy(mesh_cfg.mesh_ap.password, mesh_psk->valuestring, psk_len);
    mesh_cfg.mesh_ap.max_connection = 0; // nonmesh_max_connection = 0 (only mesh nodes)

    // Set mesh ID (e.g. 6-byte network identifier)
    // For demonstration, copy first 6 bytes or convert hex string
    memset(mesh_cfg.mesh_id.addr, 0, 6);
    strncpy((char *)mesh_cfg.mesh_id.addr, mesh_id->valuestring, 6);

    mesh_cfg.channel = 0; // Dynamic router channel sync
    mesh_cfg.router.ssid_len = 0; // Populated from standard wifi_prov_mgr config

    esp_mesh_set_config(&mesh_cfg);
    esp_mesh_set_max_layer(mesh_layer ? mesh_layer->valueint : 6);

    cJSON_Delete(root);
    return ESP_OK;
}

/**
 * @brief Custom Protocomm endpoint handler for "sw-config"
 */
esp_err_t sw_config_data_handler(uint32_t session_id,
                                 const uint8_t *inbuf, ssize_t inlen,
                                 uint8_t **outbuf, ssize_t *outlen,
                                 void *priv_data)
{
    ESP_LOGI(TAG, "Received custom endpoint 'sw-config' payload (len: %d)", (int)inlen);

    if (inbuf == NULL || inlen <= 0) {
        return send_json_response("error", "Empty payload", outbuf, outlen);
    }

    // Allocate temporary null-terminated string for cJSON
    char *json_str = (char *)malloc(inlen + 1);
    if (!json_str) {
        return send_json_response("error", "Out of memory", outbuf, outlen);
    }
    memcpy(json_str, inbuf, inlen);
    json_str[inlen] = '\0';

    esp_err_t err = parse_and_store_sw_config(json_str);
    free(json_str);

    if (err == ESP_OK) {
        return send_json_response("ok", "Configuration accepted and stored", outbuf, outlen);
    } else {
        char err_msg[64];
        snprintf(err_msg, sizeof(err_msg), "Failed to apply config: %s", esp_err_to_name(err));
        return send_json_response("error", err_msg, outbuf, outlen);
    }
}

/**
 * @brief Registers the "sw-config" endpoint with ESP-IDF unified provisioning manager.
 * Call this before wifi_prov_mgr_start_provisioning().
 */
esp_err_t register_sw_config_endpoint(void)
{
    ESP_LOGI(TAG, "Registering custom provisioning endpoint: sw-config");

    esp_err_t err = wifi_prov_mgr_endpoint_create("sw-config");
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "Failed to create endpoint 'sw-config': %s", esp_err_to_name(err));
        return err;
    }

    err = wifi_prov_mgr_endpoint_register("sw-config", sw_config_data_handler, NULL);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "Failed to register endpoint 'sw-config': %s", esp_err_to_name(err));
        return err;
    }

    ESP_LOGI(TAG, "Endpoint 'sw-config' registered successfully");
    return ESP_OK;
}
