.intel_syntax noprefix
.code32
.section .text
.global rf_setvideomode
.global rf_flip
.global rf_open_audio
.global rf_hook_music
.global rf_poll_event

.equ IAT_LoadLibraryA,      0x42f0b0
.equ IAT_GetProcAddress,    0x42f064
.equ IAT_SDL_SetVideoMode,  0x42f12c
.equ IAT_SDL_LockSurface,   0x42f16c
.equ IAT_SDL_Flip,          0x42f118
.equ IAT_SDL_UnlockSurface, 0x42f170
.equ IAT_SDL_PollEvent,    0x42f104
.equ IAT_Mix_OpenAudio,     0x42f1b4
.equ IAT_Mix_HookMusic,      0x42f1bc

# Writable state in .rfdata at 0x0043B000.
.equ g_api_ready,         0x43b000
.equ g_dpi_tried,         0x43b004
.equ g_hwnd,              0x43b008
.equ g_surface,           0x43b00c
.equ g_out_w,             0x43b010
.equ g_out_h,             0x43b014
.equ g_dest_x,            0x43b018
.equ g_dest_y,            0x43b01c
.equ g_dest_w,            0x43b020
.equ g_dest_h,            0x43b024
.equ pGetActiveWindow,    0x43b028
.equ pSetWindowLongA,     0x43b02c
.equ pSetWindowPos,       0x43b030
.equ pGetDC,              0x43b034
.equ pReleaseDC,          0x43b038
.equ pSetProcessDPIAware, 0x43b03c
.equ pPatBlt,             0x43b040
.equ pStretchDIBits,      0x43b044
.equ g_memdc,             0x43b048
.equ g_membmp,            0x43b04c
.equ g_oldbmp,            0x43b050
.equ pCreateCompatibleDC, 0x43b054
.equ pCreateCompatBitmap, 0x43b058
.equ pSelectObject,       0x43b05c
.equ pBitBlt,             0x43b060
.equ g_volume_pct,         0x43b064
.equ g_volume_scale,       0x43b068
.equ pMixVolume,           0x43b06c
.equ g_music_cb,            0x43b070
.equ g_music_udata,         0x43b074

# Keep Road Fighter's logical 512x384 software surface. Enlarge the *same*
# SDL-owned HWND to the requested output size, preserving focus/audio semantics.
rf_setvideomode:
    push ebp
    mov ebp, esp
    push ebx
    push esi
    push edi

    cmp dword ptr [g_api_ready], 1
    je .sv_api_checked
    call init_winapi
.sv_api_checked:
    cmp dword ptr [g_dpi_tried], 1
    je .sv_call_sdl
    mov dword ptr [g_dpi_tried], 1
    mov eax, dword ptr [pSetProcessDPIAware]
    test eax, eax
    jz .sv_call_sdl
    call eax

.sv_call_sdl:
    mov eax, dword ptr [ebp+20]
    and eax, 0x7fffffff             # clear SDL_FULLSCREEN
    or  eax, 0x20                   # SDL_NOFRAME
    push eax
    push 32
    push 384
    push 512
    call dword ptr [IAT_SDL_SetVideoMode]
    add esp, 16
    mov esi, eax
    test esi, esi
    jz .sv_done
    mov dword ptr [g_surface], esi

    cmp dword ptr [g_api_ready], 1
    jne .sv_done

    call dword ptr [pGetActiveWindow]
    mov dword ptr [g_hwnd], eax
    test eax, eax
    jz .sv_done

    push 0x90000000                 # WS_POPUP | WS_VISIBLE
    push -16                        # GWL_STYLE
    push eax
    call dword ptr [pSetWindowLongA]

    push 0x0060                     # SWP_FRAMECHANGED | SWP_SHOWWINDOW
    push dword ptr [g_out_h]
    push dword ptr [g_out_w]
    push 0
    push 0
    push 0                          # HWND_TOP
    push dword ptr [g_hwnd]
    call dword ptr [pSetWindowPos]

    call calc_dest_rect
    call setup_backbuffer

.sv_done:
    mov eax, esi
    pop edi
    pop esi
    pop ebx
    pop ebp
    ret

# Present with an off-screen GDI backbuffer. The visible HWND only receives one
# BitBlt per frame; black bars and scaling happen entirely off-screen first.
rf_flip:
    push ebp
    mov ebp, esp
    push ebx
    push esi
    push edi

    mov esi, dword ptr [ebp+8]
    test esi, esi
    jz .flip_fail
    cmp dword ptr [g_api_ready], 1
    jne .flip_fallback
    cmp dword ptr [g_hwnd], 0
    je .flip_fallback
    cmp dword ptr [g_memdc], 0
    je .flip_fallback

    push esi
    call dword ptr [IAT_SDL_LockSurface]
    add esp, 4
    test eax, eax
    jne .flip_fail

    # Build the entire next output frame in the invisible memory DC.
    push 0x00000042                 # BLACKNESS
    push dword ptr [g_out_h]
    push dword ptr [g_out_w]
    push 0
    push 0
    push dword ptr [g_memdc]
    call dword ptr [pPatBlt]

    push 0x00cc0020                 # SRCCOPY
    push 0                          # DIB_RGB_COLORS
    push offset bmi
    mov eax, dword ptr [esi+0x14]   # SDL_Surface::pixels
    push eax
    push 384
    push 512
    push 0
    push 0
    push dword ptr [g_dest_h]
    push dword ptr [g_dest_w]
    push dword ptr [g_dest_y]
    push dword ptr [g_dest_x]
    push dword ptr [g_memdc]
    call dword ptr [pStretchDIBits]

    # Only now touch the visible HWND: one complete frame in one BitBlt.
    push dword ptr [g_hwnd]
    call dword ptr [pGetDC]
    mov edi, eax
    test edi, edi
    jz .flip_unlock_fail

    push 0x00cc0020                 # SRCCOPY
    push 0
    push 0
    push dword ptr [g_memdc]
    push dword ptr [g_out_h]
    push dword ptr [g_out_w]
    push 0
    push 0
    push edi
    call dword ptr [pBitBlt]

    push edi
    push dword ptr [g_hwnd]
    call dword ptr [pReleaseDC]

    push esi
    call dword ptr [IAT_SDL_UnlockSurface]
    add esp, 4
    xor eax, eax
    jmp .flip_done

.flip_unlock_fail:
    push esi
    call dword ptr [IAT_SDL_UnlockSurface]
    add esp, 4
.flip_fail:
    mov eax, -1
    jmp .flip_done

.flip_fallback:
    push esi
    call dword ptr [IAT_SDL_Flip]
    add esp, 4

.flip_done:
    pop edi
    pop esi
    pop ebx
    pop ebp
    ret

# Open SDL_mixer with a larger buffer (4096 instead of the original 2048)
# to add scheduling headroom. Volume is applied *before* final mixing:
# - music: our wrapper attenuates the custom Mix_HookMusic stream
# - effects: Mix_Volume(-1, ...) attenuates all mixer channels
# This preserves headroom and avoids merely making already-clipped output quieter.
rf_open_audio:
    push ebp
    mov ebp, esp
    push ebx
    push esi
    push edi

    push 4096                         # original game requests 2048
    push dword ptr [ebp+16]
    push dword ptr [ebp+12]
    push dword ptr [ebp+8]
    call dword ptr [IAT_Mix_OpenAudio]
    add esp, 16
    mov ebx, eax
    test eax, eax
    jne .oa_done

    cmp dword ptr [pMixVolume], 0
    jne .oa_apply
    push offset str_sdl_mixer
    call dword ptr [IAT_LoadLibraryA]
    mov esi, eax
    test esi, esi
    jz .oa_done
    push offset str_Mix_Volume
    push esi
    call dword ptr [IAT_GetProcAddress]
    mov dword ptr [pMixVolume], eax

.oa_apply:
    call apply_channel_volume
.oa_done:
    mov eax, ebx
    pop edi
    pop esi
    pop ebx
    pop ebp
    ret

# Intercept Road Fighter's custom music hook. SDL_mixer runs this before adding
# sound-effect channels, so scaling here creates real headroom for the later mix.
rf_hook_music:
    push ebp
    mov ebp, esp
    mov eax, dword ptr [ebp+8]
    test eax, eax
    jz .hm_disable
    mov dword ptr [g_music_cb], eax
    mov eax, dword ptr [ebp+12]
    mov dword ptr [g_music_udata], eax
    push 0
    push offset rf_music_premix
    call dword ptr [IAT_Mix_HookMusic]
    add esp, 8
    pop ebp
    ret
.hm_disable:
    mov dword ptr [g_music_cb], 0
    mov dword ptr [g_music_udata], 0
    push dword ptr [ebp+12]
    push 0
    call dword ptr [IAT_Mix_HookMusic]
    add esp, 8
    pop ebp
    ret

# Custom music wrapper for AUDIO_S16LSB stereo. First run the game's original
# decoder callback, then attenuate that music buffer before SDL_mixer adds SFX.
rf_music_premix:
    push ebp
    mov ebp, esp
    push eax
    push ecx
    push edx
    push esi
    push edi

    mov eax, dword ptr [g_music_cb]
    test eax, eax
    jz .mp_done
    push dword ptr [ebp+16]           # len
    push dword ptr [ebp+12]           # stream
    push dword ptr [g_music_udata]
    call eax
    add esp, 12

    mov edi, dword ptr [ebp+12]
    mov ecx, dword ptr [ebp+16]
    shr ecx, 1                        # signed 16-bit samples
    mov esi, dword ptr [g_volume_scale]
    test ecx, ecx
    jz .mp_done
.mp_loop:
    movsx eax, word ptr [edi]
    imul eax, esi
    sar eax, 8
    mov word ptr [edi], ax
    add edi, 2
    dec ecx
    jnz .mp_loop
.mp_done:
    pop edi
    pop esi
    pop edx
    pop ecx
    pop eax
    pop ebp
    ret

# Set all SDL_mixer effect channels to the same percentage. This happens on
# the game thread, never inside an audio callback.
apply_channel_volume:
    push eax
    push ecx
    push edx
    mov edx, dword ptr [pMixVolume]
    test edx, edx
    jz .cv_done
    mov eax, dword ptr [g_volume_pct]
    imul eax, eax, 128
    add eax, 50
    xor edx, edx
    mov ecx, 100
    div ecx
    push eax
    push -1
    call dword ptr [pMixVolume]
    add esp, 8
.cv_done:
    pop edx
    pop ecx
    pop eax
    ret

# Preserve SDL_PollEvent, but listen for F9/F10 key-down events. We deliberately
# do not swallow them; Road Fighter does not use these keys in its own event
# handling, and leaving the event intact keeps SDL semantics unchanged.
rf_poll_event:
    push ebp
    mov ebp, esp
    push ebx
    push esi
    push edi

    push dword ptr [ebp+8]
    call dword ptr [IAT_SDL_PollEvent]
    add esp, 4
    mov ebx, eax
    test eax, eax
    jz .pe_done
    mov esi, dword ptr [ebp+8]
    test esi, esi
    jz .pe_done
    cmp byte ptr [esi], 2            # SDL_KEYDOWN
    jne .pe_done
    mov eax, dword ptr [esi+8]       # event.key.keysym.sym
    cmp eax, 290                     # SDLK_F9
    je .pe_down
    cmp eax, 291                     # SDLK_F10
    je .pe_up
    jmp .pe_done
.pe_down:
    mov eax, dword ptr [g_volume_pct]
    sub eax, 5
    jns .pe_store
    xor eax, eax
    jmp .pe_store
.pe_up:
    mov eax, dword ptr [g_volume_pct]
    add eax, 5
    cmp eax, 100
    jle .pe_store
    mov eax, 100
.pe_store:
    mov dword ptr [g_volume_pct], eax
    # scale = round(percent * 256 / 100)
    shl eax, 8
    add eax, 50
    xor edx, edx
    mov ecx, 100
    div ecx
    mov dword ptr [g_volume_scale], eax
    call apply_channel_volume
.pe_done:
    mov eax, ebx
    pop edi
    pop esi
    pop ebx
    pop ebp
    ret

# Allocate one output-sized compatible bitmap and select it into a memory DC.
# Process lifetime cleanup is left to Windows; the game has one video mode.
setup_backbuffer:
    push ebx
    push esi
    push edi

    mov dword ptr [g_memdc], 0
    mov dword ptr [g_membmp], 0
    mov dword ptr [g_oldbmp], 0

    push dword ptr [g_hwnd]
    call dword ptr [pGetDC]
    mov edi, eax
    test edi, edi
    jz .bb_fail

    push edi
    call dword ptr [pCreateCompatibleDC]
    mov esi, eax
    test esi, esi
    jz .bb_release_fail

    push dword ptr [g_out_h]
    push dword ptr [g_out_w]
    push edi
    call dword ptr [pCreateCompatBitmap]
    mov ebx, eax
    test ebx, ebx
    jz .bb_release_fail

    push ebx
    push esi
    call dword ptr [pSelectObject]
    test eax, eax
    jz .bb_release_fail

    mov dword ptr [g_memdc], esi
    mov dword ptr [g_membmp], ebx
    mov dword ptr [g_oldbmp], eax

    push edi
    push dword ptr [g_hwnd]
    call dword ptr [pReleaseDC]
    mov eax, 1
    jmp .bb_done

.bb_release_fail:
    push edi
    push dword ptr [g_hwnd]
    call dword ptr [pReleaseDC]
.bb_fail:
    xor eax, eax
.bb_done:
    pop edi
    pop esi
    pop ebx
    ret

# Resolve only APIs required for same-HWND borderless presentation.
init_winapi:
    push ebx
    push esi

    push offset str_user32
    call dword ptr [IAT_LoadLibraryA]
    mov esi, eax
    test esi, esi
    jz .api_fail

    push offset str_GetActiveWindow
    push esi
    call dword ptr [IAT_GetProcAddress]
    mov dword ptr [pGetActiveWindow], eax
    test eax, eax
    jz .api_fail

    push offset str_SetWindowLongA
    push esi
    call dword ptr [IAT_GetProcAddress]
    mov dword ptr [pSetWindowLongA], eax
    test eax, eax
    jz .api_fail

    push offset str_SetWindowPos
    push esi
    call dword ptr [IAT_GetProcAddress]
    mov dword ptr [pSetWindowPos], eax
    test eax, eax
    jz .api_fail

    push offset str_GetDC
    push esi
    call dword ptr [IAT_GetProcAddress]
    mov dword ptr [pGetDC], eax
    test eax, eax
    jz .api_fail

    push offset str_ReleaseDC
    push esi
    call dword ptr [IAT_GetProcAddress]
    mov dword ptr [pReleaseDC], eax
    test eax, eax
    jz .api_fail

    push offset str_SetProcessDPIAware
    push esi
    call dword ptr [IAT_GetProcAddress]
    mov dword ptr [pSetProcessDPIAware], eax

    push offset str_gdi32
    call dword ptr [IAT_LoadLibraryA]
    mov ebx, eax
    test ebx, ebx
    jz .api_fail

    push offset str_PatBlt
    push ebx
    call dword ptr [IAT_GetProcAddress]
    mov dword ptr [pPatBlt], eax
    test eax, eax
    jz .api_fail

    push offset str_StretchDIBits
    push ebx
    call dword ptr [IAT_GetProcAddress]
    mov dword ptr [pStretchDIBits], eax
    test eax, eax
    jz .api_fail

    push offset str_CreateCompatibleDC
    push ebx
    call dword ptr [IAT_GetProcAddress]
    mov dword ptr [pCreateCompatibleDC], eax
    test eax, eax
    jz .api_fail

    push offset str_CreateCompatibleBitmap
    push ebx
    call dword ptr [IAT_GetProcAddress]
    mov dword ptr [pCreateCompatBitmap], eax
    test eax, eax
    jz .api_fail

    push offset str_SelectObject
    push ebx
    call dword ptr [IAT_GetProcAddress]
    mov dword ptr [pSelectObject], eax
    test eax, eax
    jz .api_fail

    push offset str_BitBlt
    push ebx
    call dword ptr [IAT_GetProcAddress]
    mov dword ptr [pBitBlt], eax
    test eax, eax
    jz .api_fail

    mov dword ptr [g_api_ready], 1
    mov eax, 1
    jmp .api_done
.api_fail:
    xor eax, eax
.api_done:
    pop esi
    pop ebx
    ret

# Largest centered 4:3 rectangle inside output W x H.
calc_dest_rect:
    push ebx
    push esi
    push edi

    mov eax, dword ptr [g_out_w]
    lea ecx, [eax+eax*2]            # W*3
    mov edx, dword ptr [g_out_h]
    mov ebx, edx
    shl ebx, 2                      # H*4
    cmp ecx, ebx
    jg .height_limited

    mov dword ptr [g_dest_w], eax
    lea ecx, [eax+eax*2]
    shr ecx, 2
    mov dword ptr [g_dest_h], ecx
    mov dword ptr [g_dest_x], 0
    sub edx, ecx
    sar edx, 1
    mov dword ptr [g_dest_y], edx
    jmp .rect_done

.height_limited:
    mov dword ptr [g_dest_h], edx
    mov eax, edx
    shl eax, 2
    xor edx, edx
    mov ecx, 3
    div ecx
    mov dword ptr [g_dest_w], eax
    mov ecx, dword ptr [g_out_w]
    sub ecx, eax
    sar ecx, 1
    mov dword ptr [g_dest_x], ecx
    mov dword ptr [g_dest_y], 0
.rect_done:
    pop edi
    pop esi
    pop ebx
    ret

.balign 4
bmi:
    .long 40
    .long 512
    .long -384
    .short 1
    .short 32
    .long 0
    .long 0
    .long 0
    .long 0
    .long 0
    .long 0
    .long 0

str_user32:                 .asciz "user32.dll"
str_gdi32:                  .asciz "gdi32.dll"
str_GetActiveWindow:        .asciz "GetActiveWindow"
str_SetWindowLongA:         .asciz "SetWindowLongA"
str_SetWindowPos:           .asciz "SetWindowPos"
str_GetDC:                  .asciz "GetDC"
str_ReleaseDC:              .asciz "ReleaseDC"
str_SetProcessDPIAware:     .asciz "SetProcessDPIAware"
str_PatBlt:                 .asciz "PatBlt"
str_StretchDIBits:          .asciz "StretchDIBits"
str_CreateCompatibleDC:     .asciz "CreateCompatibleDC"
str_CreateCompatibleBitmap: .asciz "CreateCompatibleBitmap"
str_SelectObject:           .asciz "SelectObject"
str_BitBlt:                 .asciz "BitBlt"
str_sdl_mixer:              .asciz "SDL_mixer.dll"
str_Mix_Volume:              .asciz "Mix_Volume"
