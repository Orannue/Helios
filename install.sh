PIP_CACHE_DIR="${PIP_CACHE_DIR:-$~/workplace/code/chenlan/pip_cache}"
TRITON_CACHE_DIR="${TRITON_CACHE_DIR:-$/workplace/code/chenlan/triton/cache}"

clear_compile_cache() {
  rm -rf "$TRITON_CACHE_DIR"
  if [ -n "${TORCHINDUCTOR_CACHE_DIR:-}" ]; then
    rm -rf "$TORCHINDUCTOR_CACHE_DIR"
  else
    rm -rf /tmp/torchinductor_*
  fi
}

pip install --cache-dir "$PIP_CACHE_DIR" -r requirements.txt

clear_compile_cache

pip uninstall triton torchao xformers wandb tensorflow tensorflow-cpu -y
pip install --cache-dir "$PIP_CACHE_DIR" wandb==0.23.0 triton==3.6.0

clear_compile_cache
