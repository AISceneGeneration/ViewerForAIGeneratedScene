import WebGL from 'three/examples/jsm/capabilities/WebGL.js';
import { Viewer } from './viewer.js';
import { SimpleDropzone } from 'simple-dropzone';
import { Validator } from './validator.js';
import { Footer } from './components/footer';
import queryString from 'query-string';
import pako from 'pako';

window.VIEWER = {};

if (!(window.File && window.FileReader && window.FileList && window.Blob)) {
  console.error('The File APIs are not fully supported in this browser.');
} else if (!WebGL.isWebGLAvailable()) {
  console.error('WebGL is not supported in this browser.');
}

class App {

  /**
   * @param  {Element} el
   * @param  {Location} location
   */
  constructor (el, location) {

    const hash = location.hash ? queryString.parse(location.hash) : {};
    this.options = {
      kiosk: Boolean(hash.kiosk),
      model: hash.model || '',
      preset: hash.preset || '',
      cameraPosition: hash.cameraPosition
        ? hash.cameraPosition.split(',').map(Number)
        : null
    };

    this.el = el;
    this.viewer = null;
    this.viewerEl = null;
    this.spinnerEl = el.querySelector('.spinner');
    this.dropEl = el.querySelector('.dropzone');
    this.inputEl = el.querySelector('#file-input');
    this.validator = new Validator(el);
    this.db = null;

    // this.createDropzone();
    this.hideSpinner();

    const options = this.options;

    if (options.kiosk) {
      const headerEl = document.querySelector('header');
      headerEl.style.display = 'none';
    }

    if (options.model) {
      this.view(options.model, '', new Map());
    }

    this.load('/GeneratedScene/Animal_Optimized_Scene.glb')
  }

  /**
   * Sets up the drag-and-drop controller.
   */
  createDropzone () {
    const dropCtrl = new SimpleDropzone(this.dropEl, this.inputEl);
    dropCtrl.on('drop', ({files}) => this.load(files));
    dropCtrl.on('dropstart', () => this.showSpinner());
    dropCtrl.on('droperror', () => this.hideSpinner());
  }

  /**
   * Sets up the view manager.
   * @return {Viewer}
   */
  createViewer () {
    this.viewerEl = document.createElement('div');
    this.viewerEl.classList.add('viewer');
    this.dropEl.innerHTML = '';
    this.dropEl.appendChild(this.viewerEl);
    this.viewer = new Viewer(this.viewerEl, this.options);
    return this.viewer;
  }

  saveModelToIndexedDB(modelName, modelData) {
    return new Promise((resolve, reject) => {
      const request = window.indexedDB.open('models', 1);
      request.onupgradeneeded = function(event) {
        this.db = event.target.result;
        const objectStore = this.db.createObjectStore('models', { keyPath: 'name' });
      };
      request.onsuccess = function(event) {
        this.db = event.target.result;
        const transaction = this.db.transaction(['models'], 'readwrite');
        const objectStore = transaction.objectStore('models');
        const data = { name: modelName, data: modelData };
        const request = objectStore.put(data);
        request.onsuccess = function(event) {
          resolve();
        };
        request.onerror = function(event) {
          reject(event.target.error);
        };
      };
      request.onerror = function(event) {
        reject(event.target.error);
      };
    });
  }

  /**
   * Loads a fileset provided by user action.
   * use indexedDB to store the file for faster loading
   * @param  {Map<string, File>} fileMap
   */
  async load (filepath) {
    // Try to get the data from indexedDB first
    const request = window.indexedDB.open('models', 1);
    request.onupgradeneeded = function(event) {
      this.db = event.target.result;
      const objectStore = this.db.createObjectStore('models', { keyPath: 'name' });
    };
    request.onsuccess = async function(event) {
      this.db = event.target.result;
      const transaction = this.db.transaction(['models'], 'readwrite');
      const objectStore = transaction.objectStore('models');
      const request = objectStore.get(filepath);
      request.onsuccess = async function(event) {
        const modelData = event.target.result;
        if (modelData) {
          console.log('load from indexedDB');
          this.view(modelData.data, '', new Map([[filepath, modelData.data]]));
          this.showSpinner();
        } else {
          console.log('load from server');
          const response = await fetch(filepath,
            {
              headers:{
                'Accept-Encoding': 'gzip',
                'Content-Encoding': 'gzip',
              }
            })
          if (!response.ok) throw new Error('Failed to load file'
            + (response.status ? `: ${response.status} ${response.statusText}` : ''));
          
          const file = await response.blob()
          const rootPath = '';
      
          this.saveModelToIndexedDB(filepath, file);
          this.view(file, rootPath, new Map([[filepath, file]]));
          this.showSpinner();
        }
      }.bind(this);
      request.onerror = function(event) {
        console.log(event.target.error);
      };
    }.bind(this);
    request.onerror = function(event) {
      console.log(event.target.error);
    };
  }

  /**
   * Passes a model to the viewer, given file and resources.
   * @param  {File|string} rootFile
   * @param  {string} rootPath
   * @param  {Map<string, File>} fileMap
   */
  view (rootFile, rootPath, fileMap) {

    if (this.viewer) this.viewer.clear();

    const viewer = this.viewer || this.createViewer();

    const fileURL = typeof rootFile === 'string'
      ? rootFile
      : URL.createObjectURL(rootFile);

    const cleanup = () => {
      this.hideSpinner();
      if (typeof rootFile === 'object') URL.revokeObjectURL(fileURL);
    };

    viewer
      .load(fileURL, rootPath, fileMap)
      .catch((e) => this.onError(e))
      .then((gltf) => {
        // Skip validation to speed up
        // if (!this.options.kiosk) {
        //   this.validator.validate(fileURL, rootPath, fileMap, gltf);
        // }
        cleanup();
      });
  }

  /**
   * @param  {Error} error
   */
  onError (error) {
    let message = (error||{}).message || error.toString();
    if (message.match(/ProgressEvent/)) {
      message = 'Unable to retrieve this file. Check JS console and browser network tab.';
    } else if (message.match(/Unexpected token/)) {
      message = `Unable to parse file content. Verify that this file is valid. Error: "${message}"`;
    } else if (error && error.target && error.target instanceof Image) {
      message = 'Missing texture: ' + error.target.src.split('/').pop();
    }
    window.alert(message);
    console.error(error);
  }

  showSpinner () {
    this.spinnerEl.style.display = '';
  }

  hideSpinner () {
    this.spinnerEl.style.display = 'none';
  }
}

document.body.innerHTML += Footer();

document.addEventListener('DOMContentLoaded', () => {

  const app = new App(document.body, location);

  window.VIEWER.app = app;

  console.info('[glTF Viewer] Debugging data exported as `window.VIEWER`.');

});

function isIFrame () {
    try {
        return window.self !== window.top;
    } catch (e) {
        return true;
    }
}

// bandwidth on this page is very high. hoping to
// figure out what percentage of that is embeds.
Tinybird.trackEvent('load', {embed: isIFrame()});
