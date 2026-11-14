<script setup>
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Input from 'dashboard/components-next/input/Input.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import whatsappTemplateUploadAPI from 'dashboard/api/channel/whatsapp/whatsappTemplateUploadAPI';

const props = defineProps({
  mediaFormat: {
    type: String,
    required: true,
  },
  mediaUrl: {
    type: String,
    default: '',
  },
  mediaName: {
    type: String,
    default: '',
  },
  blobSignedId: {
    type: String,
    default: '',
  },
  isDocumentTemplate: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits([
  'update:mediaUrl',
  'update:mediaName',
  'update:blobSignedId',
]);

const { t } = useI18n();

const fileInputRef = ref(null);
const isDragging = ref(false);
const isUploading = ref(false);
const uploadError = ref('');
const localFileName = ref(props.mediaName || '');
const localFileSize = ref('');

// Default to URL mode only if a URL is already provided without a direct upload blob.
const activeTab = ref(props.mediaUrl && !props.blobSignedId ? 'url' : 'upload');

const formatType = computed(() => {
  const format = props.mediaFormat || '';
  return format ? format.charAt(0) + format.slice(1).toLowerCase() : '';
});

const maxSizeMB = computed(() => {
  switch (props.mediaFormat?.toUpperCase()) {
    case 'IMAGE':
      return 5;
    case 'VIDEO':
      return 16;
    case 'DOCUMENT':
    default:
      return 100;
  }
});

const acceptedMimeTypes = computed(() => {
  switch (props.mediaFormat?.toUpperCase()) {
    case 'IMAGE':
      return 'image/jpeg,image/png,image/webp';
    case 'VIDEO':
      return 'video/mp4,video/3gpp,video/quicktime';
    case 'DOCUMENT':
    default:
      return '.pdf,.doc,.docx,.xls,.xlsx,.csv,.txt,application/pdf,application/msword,application/vnd.openxmlformats-officedocument.wordprocessingml.document,application/vnd.ms-excel,application/vnd.openxmlformats-officedocument.spreadsheetml.sheet,text/csv,text/plain';
  }
});

const formatBytes = bytes => {
  if (!bytes || bytes === 0) return '0 B';
  const k = 1024;
  const sizes = ['B', 'KB', 'MB', 'GB'];
  const i = Math.floor(Math.log(bytes) / Math.log(k));
  return `${parseFloat((bytes / k ** i).toFixed(1))} ${sizes[i]}`;
};

const processUpload = async file => {
  uploadError.value = '';

  const maxSizeBytes = maxSizeMB.value * 1024 * 1024;
  if (file.size > maxSizeBytes) {
    uploadError.value = t('WHATSAPP_TEMPLATES.PARSER.FILE_SIZE_LIMIT', {
      maxSize: `${maxSizeMB.value}MB`,
    });
    return;
  }

  isUploading.value = true;
  localFileName.value = file.name;
  localFileSize.value = formatBytes(file.size);

  try {
    const data = await whatsappTemplateUploadAPI.uploadMedia(file);
    emit('update:mediaUrl', data.file_url);
    emit('update:blobSignedId', data.blob_signed_id);

    if (props.isDocumentTemplate && !props.mediaName) {
      emit('update:mediaName', data.file_name);
    }
  } catch (error) {
    uploadError.value =
      error?.response?.data?.error ||
      t('WHATSAPP_TEMPLATES.PARSER.UPLOAD_ERROR');
    localFileName.value = '';
    localFileSize.value = '';
  } finally {
    isUploading.value = false;
  }
};

const handleFileSelect = event => {
  const file = event.target?.files?.[0];
  if (file) {
    processUpload(file);
  }
  if (fileInputRef.value) {
    fileInputRef.value.value = '';
  }
};

const handleDrop = event => {
  isDragging.value = false;
  const file = event.dataTransfer?.files?.[0];
  if (file) {
    processUpload(file);
  }
};

const triggerFileInput = () => {
  fileInputRef.value?.click();
};

const handleRemove = () => {
  emit('update:mediaUrl', '');
  emit('update:blobSignedId', '');
  emit('update:mediaName', '');
  localFileName.value = '';
  localFileSize.value = '';
  uploadError.value = '';
};

const handleUrlChange = value => {
  emit('update:mediaUrl', value);
  emit('update:blobSignedId', '');
};

const handleDocumentNameChange = value => {
  emit('update:mediaName', value);
};
</script>

<template>
  <div class="flex flex-col gap-3">
    <!-- Header & Mode Tabs -->
    <div class="flex items-center justify-between">
      <p class="text-sm font-semibold text-n-slate-12">
        {{
          $t('WHATSAPP_TEMPLATES.PARSER.MEDIA_HEADER_LABEL', {
            type: formatType,
          }) || `${formatType} Header`
        }}
      </p>

      <div
        class="flex items-center gap-1 p-0.5 rounded-lg bg-n-alpha-black2 dark:bg-n-solid-3"
      >
        <button
          type="button"
          class="px-2.5 py-1 text-xs font-medium rounded-md transition-colors"
          :class="
            activeTab === 'upload'
              ? 'bg-n-solid-1 text-n-slate-12 shadow-sm dark:bg-n-solid-4'
              : 'text-n-slate-11 hover:text-n-slate-12'
          "
          @click="activeTab = 'upload'"
        >
          {{ $t('WHATSAPP_TEMPLATES.PARSER.UPLOAD_TAB') }}
        </button>
        <button
          type="button"
          class="px-2.5 py-1 text-xs font-medium rounded-md transition-colors"
          :class="
            activeTab === 'url'
              ? 'bg-n-solid-1 text-n-slate-12 shadow-sm dark:bg-n-solid-4'
              : 'text-n-slate-11 hover:text-n-slate-12'
          "
          @click="activeTab = 'url'"
        >
          {{ $t('WHATSAPP_TEMPLATES.PARSER.URL_TAB') }}
        </button>
      </div>
    </div>

    <!-- Hidden file input -->
    <input
      ref="fileInputRef"
      type="file"
      :accept="acceptedMimeTypes"
      class="hidden"
      @change="handleFileSelect"
    />

    <!-- Upload Tab View -->
    <div v-if="activeTab === 'upload'">
      <!-- Uploading state -->
      <div
        v-if="isUploading"
        class="flex flex-col items-center justify-center p-6 border-2 border-dashed rounded-lg border-n-slate-6 bg-n-alpha-black2 gap-2"
      >
        <Spinner :size="24" />
        <p class="text-xs font-medium text-n-slate-11">
          {{
            $t('WHATSAPP_TEMPLATES.PARSER.UPLOADING', {
              filename: localFileName,
            })
          }}
        </p>
      </div>

      <!-- Uploaded file card -->
      <div
        v-else-if="mediaUrl && blobSignedId"
        class="flex items-center justify-between p-3 rounded-lg border border-n-slate-6 bg-n-alpha-black2 dark:bg-n-solid-2"
      >
        <div class="flex items-center gap-3 overflow-hidden">
          <div
            v-if="mediaFormat === 'IMAGE'"
            class="w-12 h-12 flex-shrink-0 rounded-md overflow-hidden bg-n-solid-3 border border-n-slate-5 flex items-center justify-center"
          >
            <img
              :src="mediaUrl"
              :alt="localFileName || 'Image preview'"
              class="w-full h-full object-cover"
            />
          </div>
          <div
            v-else
            class="w-12 h-12 flex-shrink-0 rounded-md bg-n-solid-3 dark:bg-n-solid-4 flex items-center justify-center text-n-slate-11"
          >
            <span
              v-if="mediaFormat === 'VIDEO'"
              class="i-lucide-video text-xl"
            />
            <span v-else class="i-lucide-file-text text-xl" />
          </div>

          <div class="flex flex-col min-w-0">
            <span class="text-sm font-medium text-n-slate-12 truncate">
              {{ localFileName || mediaName || `${formatType} file` }}
            </span>
            <div class="flex items-center gap-2 text-xs text-n-slate-11">
              <span v-if="localFileSize">{{ localFileSize }}</span>
              <span class="inline-flex items-center text-n-teal-11 font-medium">
                <span class="i-lucide-check text-xs me-1" />
                {{ $t('WHATSAPP_TEMPLATES.PARSER.UPLOAD_SUCCESS') }}
              </span>
            </div>
          </div>
        </div>

        <div class="flex items-center gap-1 flex-shrink-0 ms-2">
          <Button
            size="xs"
            color="slate"
            variant="ghost"
            :label="$t('WHATSAPP_TEMPLATES.PARSER.REPLACE_FILE')"
            @click="triggerFileInput"
          />
          <Button
            size="xs"
            color="ruby"
            variant="ghost"
            icon="i-lucide-trash"
            @click="handleRemove"
          />
        </div>
      </div>

      <!-- Empty dropzone state -->
      <div
        v-else
        class="flex flex-col items-center justify-center p-6 border-2 border-dashed rounded-lg cursor-pointer transition-colors"
        :class="
          isDragging
            ? 'border-n-brand bg-n-brand/5 dark:bg-n-brand/10'
            : 'border-n-slate-6 hover:border-n-slate-7 bg-n-alpha-black2'
        "
        @click="triggerFileInput"
        @dragover.prevent="isDragging = true"
        @dragleave.prevent="isDragging = false"
        @drop.prevent="handleDrop"
      >
        <div
          class="p-2.5 mb-2 rounded-full bg-n-solid-3 dark:bg-n-solid-4 text-n-slate-11"
        >
          <span
            v-if="mediaFormat === 'IMAGE'"
            class="i-lucide-image text-xl block"
          />
          <span
            v-else-if="mediaFormat === 'VIDEO'"
            class="i-lucide-video text-xl block"
          />
          <span v-else class="i-lucide-upload-cloud text-xl block" />
        </div>
        <p class="text-xs font-medium text-n-slate-12 mb-1">
          {{ $t('WHATSAPP_TEMPLATES.PARSER.UPLOAD_PROMPT') }}
        </p>
        <p class="text-[11px] text-n-slate-11">
          {{
            $t('WHATSAPP_TEMPLATES.PARSER.UPLOAD_HELP_TEXT', {
              type: formatType,
              maxSize: `${maxSizeMB}MB`,
            })
          }}
        </p>
      </div>

      <!-- Upload error alert -->
      <p v-if="uploadError" class="mt-1.5 text-xs text-n-ruby-9 font-medium">
        {{ uploadError }}
      </p>
    </div>

    <!-- URL Tab View -->
    <div v-else class="flex flex-col gap-2">
      <Input
        :model-value="mediaUrl"
        type="url"
        class="w-full"
        :placeholder="
          t('WHATSAPP_TEMPLATES.PARSER.MEDIA_URL_LABEL', {
            type: formatType,
          })
        "
        @update:model-value="handleUrlChange"
      />
    </div>

    <!-- Document name input (always visible if document template) -->
    <div v-if="isDocumentTemplate" class="flex flex-col gap-1">
      <Input
        :model-value="mediaName"
        type="text"
        class="w-full"
        :placeholder="t('WHATSAPP_TEMPLATES.PARSER.DOCUMENT_NAME_PLACEHOLDER')"
        @update:model-value="handleDocumentNameChange"
      />
    </div>
  </div>
</template>
