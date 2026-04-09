package com.example.crm_caller_nxtgen.overlay.ui

import android.app.Service
import android.content.Context
import android.os.Bundle
import android.view.View
import androidx.lifecycle.*
import androidx.savedstate.SavedStateRegistry
import androidx.savedstate.SavedStateRegistryController
import androidx.savedstate.SavedStateRegistryOwner

class WindowLifecycleOwner : LifecycleOwner, ViewModelStoreOwner, SavedStateRegistryOwner {

    private val mLifecycleRegistry = LifecycleRegistry(this)
    private val mSavedStateRegistryController = SavedStateRegistryController.create(this)
    private val mViewModelStore = ViewModelStore()

    override val lifecycle: Lifecycle
        get() = mLifecycleRegistry

    override val savedStateRegistry: SavedStateRegistry
        get() = mSavedStateRegistryController.savedStateRegistry

    override val viewModelStore: ViewModelStore
        get() = mViewModelStore

    fun onCreate() {
        mSavedStateRegistryController.performRestore(Bundle())
        mLifecycleRegistry.handleLifecycleEvent(Lifecycle.Event.ON_CREATE)
    }

    fun onStart() {
        mLifecycleRegistry.handleLifecycleEvent(Lifecycle.Event.ON_START)
    }

    fun onResume() {
        mLifecycleRegistry.handleLifecycleEvent(Lifecycle.Event.ON_RESUME)
    }

    fun onPause() {
        mLifecycleRegistry.handleLifecycleEvent(Lifecycle.Event.ON_PAUSE)
    }

    fun onStop() {
        mLifecycleRegistry.handleLifecycleEvent(Lifecycle.Event.ON_STOP)
    }

    fun onDestroy() {
        mLifecycleRegistry.handleLifecycleEvent(Lifecycle.Event.ON_DESTROY)
        mViewModelStore.clear()
    }

    /**
     * Attach this owner to a view tree and register the view tree to these owners.
     */
    fun attachTo(view: View) {
        // Fallback to manual tag setting if extension functions fail to resolve
        view.setTag(androidx.lifecycle.runtime.R.id.view_tree_lifecycle_owner, this)
        view.setTag(androidx.savedstate.R.id.view_tree_saved_state_registry_owner, this)
        view.setTag(androidx.lifecycle.viewmodel.R.id.view_tree_view_model_store_owner, this)
    }
}
